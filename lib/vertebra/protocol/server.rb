# Copyright 2008, Engine Yard, Inc.
#
# This file is part of Vertebra.
#
# Vertebra is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# Vertebra is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Vertebra.  If not, see <http://www.gnu.org/licenses/>.

module Vertebra
	module Protocol
		# The server is a simple state machine with the following states:
		#
		# Verify
		# Producing
		# Flush
		# Commit
		#
		# When the request is received, verification is done. The semantics of this
		# vary depending on the operation.
		# An Acknowledgement or Negative Acknowledgement response is sent and the
		# reply triggers state change to the Producing state.
		#
		# In the Producing state, "result" stanzas are sent in rapid succession.
		# When no more results will be generated, the Flush state is entered.
		#
		# In the Flush state, any outstanding "result" confirmations are collected.
		#
		# In the Commit state, the "final" stanza is sent, effectively signaling
		# that the sender is finished.

		class Server

			attr_accessor :token, :agent, :state

			def initialize(agent,iq)
				@agent = agent
				@state = :new
				receiver = Vertebra::Synapse.new
				receiver.callback do
					receive_request(iq)
				end
				logger.debug "enqueue receiver"
				@agent.enqueue_synapse(receiver)
			end

			def receive_request(iq)
				logger.debug "Server#receive_request#{iq}"
				@iq = iq
				@op = op = iq.node.find_child('op')
				self.token = op.get_attribute('token').split(':').last << ":#{Vertebra.gen_token}"
				op.set_attribute("token", token)
			
				result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ)
				result_iq.node.raw_mode = true
				result_iq.node.set_attribute("id", iq.root_node.get_attribute("id"))        
				result_iq.root_node.set_attribute('type', 'result')
				result_iq.node.value = op
				responder = Vertebra::Synapse.new
				responder.callback do
					@agent.client.send(result_iq)
					@state = :verify
					process_authorization
				end
				@agent.enqueue_synapse(responder)
			end

			def process_authorization
				logger.debug "Server#process_authorization"
				op = @iq.node.get_child('op')
				rexml_op = REXML::Document.new(op.to_s).root
				res = []

				rexml_op.children.each do |el|
      		next if el.is_a?(REXML::Text)
      		res << el.text if el.name == 'res' 
      	end
				res << {'from' => @iq.node.get_attribute("from").to_s, 'to' => @iq.node.get_attribute("to").to_s}

        authorizer = Vertebra::Synapse.new
        authorizer.callback do
          auth_client = @agent.direct_op('/security/authorize', @agent.herault_jid, *res)
          
          # TODO: Should this have a timeout on it? I think probably, yes.
          verifier = Vertebra::Synapse.new
          verifier.condition { auth_client.done? ? true : :deferred }
          verifier.callback do
            if auth_client.results['response'] == 'authorized'
              process_authorized
            else
              process_not_authorized
            end
          end
          @agent.enqueue_synapse(verifier)
        end
        @agent.enqueue_synapse(authorizer)
			end

			def process_authorized
				logger.debug "Server#process_authorized"
				iq = LM::Message.new(@iq.node.get_attribute("from"), LM::MessageType::IQ)
				iq.root_node.set_attribute('type', 'set')
				ack = Vertebra::Ack.new(token)
				iq.node.raw_mode = true
				iq.node.value = ack.to_s
				
				acknowledger = Vertebra::Synapse.new
				acknowledger.callback do
					@agent.client.send_with_reply(iq) do |answer|
						if answer.sub_type == LM::MessageSubType::RESULT
							process_operation
						else
							process_terminate
						end
					end
				end
				@agent.enqueue_synapse(acknowledger)
			end

			def process_not_authorized
				logger.debug "Server#process_not_authorized"
				iq = LM::Message.new(@iq.node.get_attribute("from"), LM::MessageType::IQ)
				iq.root_node.set_attribute('type', 'set')
				nack = Vertebra::Nack.new(token)
				iq.node.raw_mode = true
				iq.node.value = nack.to_s
				terminator = Vertebra::Synapse.new
				terminator.callback do
          # This is probably wrong; I am betting this code should probably
          # expect the response to the nack, so that it can retry.
					@agent.client.send(iq)
					process_terminate
				end
				@agent.enqueue_synapse(terminator)
			end

			def process_operation
        # TODO: somehow this will have to be decoupled so that a long running op
        # can defer itself so that the event loop is not blocked.
				@state = :producing
				logger.debug "Server#process_operation: #{@iq.node.get_child('op').to_s}"
				dispatcher = Vertebra::Synapse.new
				dispatcher.callback do
          result_iq = nil
          notifier = Vertebra::Synapse.new
          
          begin
            logger.debug "handling #{@op}"
            @agent.dispatcher.handle(@op) do |response, final|
          		result_iq = LM::Message.new(@iq.node.get_attribute("from"), LM::MessageType::IQ)
        			result_iq.node.raw_mode = true
      				result_iq.node.set_attribute("id", @iq.node.get_attribute("id"))
    					result_iq.root_node.set_attribute('type', 'result')
    					logger.debug "sending #{result_iq}"
  						@agent.client.send(result_iq)

  						result_tag = Vertebra::Result.new(token)
  						Vertebra::Marshal.encode(response).children.each do |ch|
  							result_tag.add(ch)
  						end
  						result_iq.node.value = result_tag.to_s
  					end
          rescue Exception => e
          	logger.error "#{Vertebra.exception(e)}\noperation FAILED #{@op}"
      			result_tag = Vertebra::Result.new(token)
    				result_tag.attributes['status'] = 'error'
    				Vertebra::Marshal.encode({:backtrace => Vertebra.exception(e)}).children.each do |ch|
    					result_tag.add(ch)
    				end
    				result_iq = LM::Message.new(@iq.node.get_attribute("from"), LM::MessageType::IQ)
    				result_iq.node.raw_mode = true
    				result_iq.root_node.set_attribute('type', 'set')
    				result_iq.node.value = result_tag.to_s

    				notifier.callback do
          		@agent.client.send_with_reply(result_iq) {|answer| @state = :error }
    				end
    				@agent.enqueue_synapse(notifier)
    				break
          end

          logger.debug "setting up notifier for final"
          notifier.callback do
    				@agent.client.send_with_reply(result_iq) do |answer|
    					if answer.sub_type == LM::MessageSubType::RESULT
   							@state = :flush
   							final_iq = LM::Message.new(@iq.node.get_attribute("from"), LM::MessageType::IQ)
   							final_iq.root_node.set_attribute('type', 'set')
   							result_iq.node.raw_mode = true
   							final_tag = ::Vertebra::Final.new(token)
   							final_iq.node.add_child final_tag
   							@agent.client.send_with_reply(final_iq) do |answer|
   								if answer.sub_type == LM::MessageSubType::RESULT
   									@state = :commit
   								end
   							end
            	end
        		end
          end
          @agent.enqueue_synapse(notifier)
				end
				@agent.enqueue_synapse(dispatcher)
			end

			def process_terminate
				logger.error "terminating op!:#{@op}"
				:terminated
			end

		end

	end # Protocol

end # Vertebra
