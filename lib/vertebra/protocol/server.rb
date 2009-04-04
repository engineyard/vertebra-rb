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

      attr_accessor :agent, :job, :state, :last_message_sent

      def initialize(agent, iq)
        @agent = agent
        @state = :new
        @final_countdown = 0
        @iq = iq

        token = op_node['token'].split(':').last << ":#{Vertebra.gen_token}"
        op_node["token"] = token

        element = REXML::Document.new(op_node.to_s).root
        args = Vertebra::Marshal.decode(element)
        @job = Job.new(Resource.parse(op_node['type']), token, op_node['scope'], iq.node['from'], iq.node['to'], args)
        logger.debug "New job is #{@job.inspect}"

        receiver = Vertebra::Synapse.new
        receiver.callback do
          receive_request
        end
        logger.debug "enqueue receiver"
        @agent.do_or_enqueue_synapse(receiver)
      end

      def token
        @job.token
      end

      def operation
        @job.operation
      end

      def from
        @job.from
      end

      def to
        @job.to
      end

      def args
        @job.args
      end

      def op_node
        @iq.node.get_child('op')
      end

      def receive_request
        logger.debug "Server#receive_request: #{@iq}"
        @agent.servers[token] = self

        result_iq = LM::Message.new(from, LM::MessageType::IQ)
        result_iq.node.raw_mode = false
        result_iq.node["id"] = @iq.root_node["id"]
        result_iq.root_node['type'] = 'result'
        result_iq.node.add_child op_node.name
        result_iq.node.child["token"] = token
        responder = Vertebra::Synapse.new
        responder.condition { @agent.connection_is_open_and_authenticated? }
        responder.callback do
          @last_message_sent = result_iq
          @agent.send_iq(result_iq)
          @state = :verify
          if @agent.herault_jid
            process_authorization
          else
            process_authorized
          end
        end
        @agent.do_or_enqueue_synapse(responder)
      end

      def process_authorization
        logger.debug "Server#process_authorization"

        resources = Vertebra::Utils.resources_from_args(args)
        authorize_args = {"job" => {"operation" => operation, "from" => from, "to" => to, "resources" => resources}}

        @agent.request('/security/authorize', :direct, authorize_args, [@agent.herault_jid]) do |results|
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
        iq.root_node['type'] = 'set'
        ack = Vertebra::Ack.new(token)
        iq.node.raw_mode = false
        iq.node.add_child ack

        acknowledger = Vertebra::Synapse.new
        acknowledger.condition { @agent.connection_is_open_and_authenticated? }
        acknowledger.callback do
          @last_message_sent = iq
          @agent.packet_memory.set(iq.node['to'], token, iq.node['id'],iq)
          @agent.send_iq(iq)
        end
        @agent.do_or_enqueue_synapse(acknowledger)
      end

      def process_not_authorized
        logger.debug "Server#process_not_authorized"
        iq = LM::Message.new(from, LM::MessageType::IQ)
        iq.root_node['type'] = 'set'
        nack = Vertebra::Nack.new(token)
        iq.node.raw_mode = false
        iq.node.add_child nack
        terminator = Vertebra::Synapse.new
        terminator.condition { @agent.connection_is_open_and_authenticated? }
        terminator.callback do
          @last_message_sent = iq
          @agent.packet_memory.set(iq.node['to'], token, iq.node['id'],iq)
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

          logger.debug "handling #{job.inspect}"
          ops_bucket = nil

          ops_bucket = @agent.dispatcher.handle(job)

          if ops_bucket
            bucket_handler = Vertebra::Synapse.new
            bucket_handler.condition do
              ops_bucket.has_key?(:results) ? :succeeded : :deferred
            end

            bucket_handler.callback do
              result_iqs = []
              ops_bucket[:results].each do |result|
                result_iq = LM::Message.new(from, LM::MessageType::IQ)
                result_iq.root_node['type'] = 'set'

                logger.debug "RESULT: #{result.inspect}"
                result_tag = Vertebra::Data.new(token)
                Vertebra::Marshal.encode({:response => result}).children.each do |child|
                  result_tag.add(child)
                end
                logger.debug "ADDING: #{result_tag}"

                result_iq.root_node.raw_mode = false
                result_iq.root_node.add_child result_tag
                logger.debug "FULL IQ: #{result_iq.node}"

                result_iqs << result_iq
              end

              notifier = Vertebra::Synapse.new
              notifier.condition { @agent.connection_is_open_and_authenticated? }

              notifier.callback do
                result_iqs.each do |iq|
                  @final_countdown += 1
                  @agent.packet_memory.set(iq.node['to'], token, iq.node['id'],iq)
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
              @agent.packet_memory.set(iq.node['to'], token, iq.node['id'],iq)
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
          final_iq.root_node['type'] = 'set'
          final_iq.node.raw_mode = true
          final_tag = ::Vertebra::Final.new(token)
          final_iq.node.add_child final_tag
          logger.debug "  Send Final"
          @agent.packet_memory.set(final_iq.node['to'], token, final_iq.node['id'],final_iq)
          @agent.send_iq(final_iq)
        end
      end

      def process_final
        @agent.packet_memory.delete_by_token(@iq.node['token'])
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
