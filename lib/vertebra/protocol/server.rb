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
    # In the Producing state, "data" stanzas are sent in rapid succession.
    # When no more results will be generated, the Flush state is entered.
    #
    # In the Flush state, any outstanding "result" confirmations are collected.
    #
    # In the Commit state, the "final" stanza is sent, effectively signaling
    # that the sender is finished.

    class Server

      attr_accessor :token, :agent, :state, :last_message_sent

      def initialize(agent,iq)
        @agent = agent
        @state = :new
        @final_countdown = 0
        @iq = iq

        receiver = Vertebra::Synapse.new
        receiver.callback do
          receive_request
        end
        logger.debug "enqueue receiver"
        @agent.do_or_enqueue_synapse(receiver)
      end

      def from
        @iq.node.get_attribute("from")
      end

      def to
        @iq.node.get_attribute("to")
      end

      def op
        @iq.node.get_child('op')
      end

      def operation
        @operation ||= Struct.new(:from).new(from)
      end

      def receive_request
        logger.debug "Server#receive_request: #{@iq}"
        self.token = op.get_attribute('token').split(':').last << ":#{Vertebra.gen_token}"
        op.set_attribute("token", token)
        @agent.servers[token] = self

        result_iq = LM::Message.new(from, LM::MessageType::IQ)
        result_iq.node.raw_mode = false
        result_iq.node.set_attribute("id", @iq.root_node.get_attribute("id"))
        result_iq.root_node.set_attribute('type', 'result')
        #result_iq.node.value = op
        result_iq.node.add_child op.name
        result_iq.node.child.set_attribute("token", token)
        responder = Vertebra::Synapse.new
        responder.condition { @agent.connection_is_open_and_authenticated? }
        responder.callback do
          @last_message_sent = result_iq
          @agent.send_iq(result_iq)
          @state = :verify
          if @agent.opts[:herault_jid]
            process_authorization
          else
            process_authorized
          end
        end
        @agent.do_or_enqueue_synapse(responder)
      end

      def process_authorization
        logger.debug "Server#process_authorization"
        rexml_op = REXML::Document.new(op.to_s).root
        res = {}

        rexml_op.children.each do |el|
          next if el.is_a?(REXML::Text)
          res[el.text] = el.text if el.name == 'res'
        end
        res['from'] = from
        res['to'] = to

        @agent.request('/security/authorize', :direct, res, [@agent.herault_jid]) do |results|
          if results['response'] == 'authorized'
            process_authorized
          else
            process_not_authorized
          end
        end
      end

      def process_authorized
        logger.debug "Server#process_authorized"
        iq = LM::Message.new(from, LM::MessageType::IQ)
        iq.root_node.set_attribute('type', 'set')
        ack = Vertebra::Ack.new(token)
        iq.node.raw_mode = true
        iq.node.value = ack.to_s

        acknowledger = Vertebra::Synapse.new
        acknowledger.condition { @agent.connection_is_open_and_authenticated? }
        acknowledger.callback do
          @last_message_sent = iq
          @agent.send_iq(iq)
        end
        @agent.do_or_enqueue_synapse(acknowledger)
      end

      def process_not_authorized
        logger.debug "Server#process_not_authorized"
        iq = LM::Message.new(from, LM::MessageType::IQ)
        iq.root_node.set_attribute('type', 'set')
        nack = Vertebra::Nack.new(token)
        iq.node.raw_mode = true
        iq.node.value = nack.to_s
        terminator = Vertebra::Synapse.new
        terminator.condition { @agent.connection_is_open_and_authenticated? }
        terminator.callback do
          @last_message_sent = iq
          @agent.send_iq(iq)
        end
        @agent.do_or_enqueue_synapse(terminator)
      end

      def process_nack_result
        @agent.servers.delete @iq.node['token']
        process_terminate
      end

      def process_operation
        # TODO: somehow this will have to be decoupled so that a long running op
        # can defer itself so that the event loop is not blocked.
        # This code also needs to be refactored so it's not quite so bugly.

        @state = :producing
        logger.debug "Server#process_operation: #{@iq.node.get_child('op').to_s}"
        dispatcher = Vertebra::Synapse.new
        dispatcher.condition { @agent.connection_is_open_and_authenticated? }
        dispatcher.callback do
          result_iq = nil

          error = false

          logger.debug "handling #{op}"
          ops_bucket = nil

          begin
            ops_bucket = @agent.dispatcher.handle(operation, op)
          rescue Exception => e
            notifier = Vertebra::Synapse.new
            notifier.condition { @agent.connection_is_open_and_authenticated? }

            result_iq = LM::Message.new(from, LM::MessageType::IQ)
            logger.error "operation FAILED #{op}: #{e.class}: #{e.message}"
            logger.debug e.backtrace.inspect
            error_tag = Vertebra::Error.new(token)
            Vertebra::Marshal.encode(:error => e).children.each do |child|
              error_tag.add(child) # Insert the marshalled error XML into the error tag
            end
            result_iq.root_node.set_attribute('type','error')
            result_iq.node.add_child error_tag
            @agent.packet_memory.delete_by_token(@iq.node['token'])
            logger.debug "SENDING ERROR: #{result_iq.node}"
          end

          if ops_bucket
            bucket_handler = Vertebra::Synapse.new
            bucket_handler.condition do
              ops_bucket.has_key?(:results) ? :succeeded : :deferred
            end

            bucket_handler.callback do
              result_iqs = []
              ops_bucket[:results].each do |result|
                result_iq = LM::Message.new(from, LM::MessageType::IQ)
                result_iq.root_node.set_attribute('type', 'set')


                logger.debug "RESULT: #{result.inspect}"
                result_tag = Vertebra::Data.new(token)
                Vertebra::Marshal.encode({:response => result}).children.each do |child|
                  result_tag.add(child)
                end
                logger.debug "ADDING: #{result_tag}"

                result_iq.root_node.raw_mode = true
                result_iq.root_node.value = result_tag.to_s
                logger.debug "FULL IQ: #{result_iq.node}"

                result_iqs << result_iq
              end

              notifier = Vertebra::Synapse.new
              notifier.condition { @agent.connection_is_open_and_authenticated? }

              notifier.callback do
                result_iqs.each do |iq|
                  @final_countdown += 1
                  @agent.send_iq(iq)
                end
                # If there are no results then force sending the 'final' stanza
                process_data_result if result_iqs.empty?
              end
              @agent.do_or_enqueue_synapse(notifier)
            end

            @agent.do_or_enqueue_synapse(bucket_handler)
          else
            notifier.callback do
              @agent.send_iq(result_iq)
            end
            @agent.do_or_enqueue_synapse(notifier)
          end
        end
        @agent.do_or_enqueue_synapse(dispatcher)
      end

      def process_data_result(iq = nil)
        @final_countdown -= 1

        if @final_countdown <= 0 && @state != :flush
          @state = :flush
          final_iq = LM::Message.new(from, LM::MessageType::IQ)
          final_iq.root_node.set_attribute('type', 'set')
          final_iq.node.raw_mode = true
          final_tag = ::Vertebra::Final.new(token)
          final_iq.node.add_child final_tag
          logger.debug "  Send Final"
          @agent.send_iq(final_iq)
          @agent.packet_memory.delete_by_token(@iq.node['token'])
        end
      end

      def process_final
        @state = :commit
      end

      def process_error
        @state = :error
      end

      def process_terminate
        logger.error "terminating op!: #{op}"
        :terminated
      end

      def logger
        Vertebra.logger
      end

    end

  end # Protocol

end # Vertebra
