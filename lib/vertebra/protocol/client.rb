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

require 'vertebra/synapse'

module Vertebra
	module Protocol
		# The client follows a simple progression through a set of states.
		#
		# New
		# Ready
		# Consume
		# Commit
		#
		# These states correspond to various network communications. In the new state,
		# the client sends the initial "op" stanza and receives a token.
		#
		# In the ready state, the client waits for and responds to an Acknowledgement stanza.
		# It can also receive a Negative Acknowledgement, which causes it to enter a "Auth Fail" state.
		#
		# When the "result" stanzas start coming in, it enters the Consume state, and responds for each of them.
		#
		# When the "final" stanza comes in, it enters the Commit state, in which it signals the code
		# that all of the data has been received.

		class Client
			DONE_STATES = [:commit, :authfail, :error]

			attr_accessor :token, :agent
			attr_reader :state, :to

			def initialize(agent, op, to)
				@agent = agent
				@state = :new
				@to = to
				@op = op
				initiator = Vertebra::Synapse.new
				initiator.callback do
					make_request
				end

				@agent.enqueue_synapse(initiator)
			end

			def make_request
				requestor = Vertebra::Synapse.new
				iq = @op.to_iq(@to, @agent.jid)
				requestor.condition {logger.debug "check authentication"; @agent.connection_is_open_and_authenticated?}
				requestor.callback do
          logger.debug "in requestor callback"
					@agent.client.send_with_reply(iq) do |answer|
						logger.debug "Client#make_request got answer #{answer.node}"
						if answer.sub_type == LM::MessageSubType::RESULT
							self.token = answer.node.get_child('op')['token']
							@agent.clients[self.token] = self
							@state = :ready
						else
							@result = "Failure; a :result response was expected, but a #{answer.node.get_attribute('type')} was received."
							@state = :error
						end
						logger.debug "Client#make_request exiting send_with_id"
					end
				end

				@agent.enqueue_synapse(requestor)				
			end

			def receive(iq)
				logger.debug "Client#recieve state:#{@state} iq:#{iq.node}"
				case @state
				when :ready
					process_ack_or_nack(iq)
				when :consume
					process_result_or_final(iq)
				end
			end

			def process_ack_or_nack(iq, packet_type, packet)
        #TODO: Add state checking code so that we don't get messed up by
        #unexpected packets.
        
				logger.debug "Client#process_ack_or_nack: #{iq.node}"
				case packet_type
				when :ack
					@state = :consume
				when :nack
          @result = "Auth Failure; #{packet}"
          @state = :authfail
				end

				result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ)
				result_iq.node.raw_mode = true
				result_iq.node.set_attribute("id", iq.node.get_attribute("id"))
				result_iq.node.set_attribute('xml:lang','en')
				result_iq.node.value = packet
				result_iq.root_node.set_attribute('type', 'result')
				
        response = Vertebra::Synapse.new
        response.condition { @agent.connection_is_open_and_authenticated? }
        response.callback do
          logger.debug "Client#process_ack_or_nack: sending #{result_iq.node}"
          @agent.client.send(result_iq)
        end
        
        @agent.enqueue_synapse(response)
			end

			def process_result_or_final(iq, packet_type, packet)
				logger.debug "Client#process_result_or_final: #{iq.node}"
				case packet_type
				when :result
          raw_element = REXML::Document.new(packet.to_s).root
          (@results ||= []) << Vertebra::Marshal.decode(raw_element)
          raw_element.children.each {|e| raw_element.delete e}
				when :final
          @state = :commit
          @agent.clients.delete(token)
				end
				
				result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ, LM::MessageSubType::RESULT)
				result_iq.node.raw_mode = true
				result_iq.node.set_attribute('id', iq.node.get_attribute('id'))
				result_iq.node.value = packet
				result_iq.node.set_attribute('type', 'result')
				response = Vertebra::Synapse.new
				response.condition { @agent.connection_is_open_and_authenticated? }
				response.callback do
          logger.debug "Client#process_result_or_final: sending #{result_iq.node}"
          agent.client.send(result_iq)
				end
				
				@agent.enqueue_synapse(response)
			end

			def results
				@results ||= []
				@results.size == 1 ? @results.first : @results
			end

			def done?
				DONE_STATES.include? @state
			end
		end
	end
end
