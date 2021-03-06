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
    # When the "data" stanzas start coming in, it enters the Consume state, and responds for each of them.
    #
    # When the "final" stanza comes in, it enters the Commit state, in which it signals the code
    # that all of the data has been received.

    # TODO: In two places in the original code, an IQ stanza was being sent without
    # the protocol caring about the response.  This really is broken behavior, and
    # should be fixed.  The reason -- if that 'data' stanza doesn't arrive in a
    # reasonable amount of time, then that's a retry situation.  The way the code
    # is right now, though, that particular failure will never be detected.

    class Client
      DONE_STATES = [:commit, :authfail, :error]

      attr_reader :state, :job

      def self.start(outcall, operation, token, scope, to, args)
        new(outcall, operation, token, scope, to, args).start
      end

      def initialize(outcall, operation, token, scope, to, args)
        @outcall = outcall
        @job = Job.new(operation, token, scope, outcall.jid.to_s, to, outcall, args)
        @state = :new
      end

      def start
        initiator = Vertebra::Synapse.new
        initiator[:name] = 'initiator'
        initiator.condition { @outcall.connection_is_open_and_authenticated? }

        iq = LM::Message.new(job.to, LM::MessageType::IQ, LM::MessageSubType::SET)
        op = Vertebra::Init.new(job.token, job.operation, job.scope)

        iq.node['xml:lang'] = 'en'
        iq.node.add_child(op)
        op_lm = iq.node.get_child(op.name)

        Vertebra::Conversion::Marshal.encode(job.args).children.each do |el|
          op_lm.add_child el
        end
        logger.debug "CREATED IQ #{iq.node.to_s} with class #{iq.class}"

        @outcall.packet_memory.set(job.to, job.token, iq.node['id'], iq)
        @outcall.add_client("#{job.to};#{iq.node['id']}", self)

        initiator.callback do
          @last_message_sent = iq
          @outcall.send_iq(iq)
        end

        @outcall.do_or_enqueue_synapse(initiator)
        self
      end

      def is_ready(token)
        job.update_token(token)
        @state = :ready
      end

      def resend
        delay = @last_message_sent.node['retry_delay'].to_i || 0
        delay += 1
        @last_message_sent.node['retry_delay'] = delay.to_s
        logger.debug "Resending #{@last_message_sent.node}"
        resender = Vertebra::Synapse.new
        resender.condition { @outcall.connection_is_open_and_authenticated? }
        resender.callback do
          @outcall.send_iq(@last_message_sent)
        end

        # This algorithm provides for a slowly increasing delay between sends.
        EM.add_timer((Math.log(delay + 0.1)).to_i) { @outcall.enqueue_synapse(resender) }
      end

      def process_ack_or_nack(iq, stanza_type, stanza)
        logger.debug "Client#process_ack_or_nack: #{iq.node}"
        case stanza_type
        when :ack
          @state = :consume
        when :nack
          @result = "Auth Failure; #{stanza}"
          @state = :authfail
        end

        @last_message_sent = @outcall.send_result(iq.node["from"], iq.node["id"])
      end

      def process_data_or_final(iq, stanza_type, stanza)
        logger.debug "Client#process_data_or_final: #{iq.node}"
        @partial_data ||= []
        @results ||= []
        case stanza_type
        when :result
          raw_element = REXML::Document.new(stanza.to_s).root
          decoded_data = Vertebra::Conversion::Marshal.decode(raw_element)
          # TODO: Ideally, this should be calling some callback block with the element.
          @results << Vertebra::Conversion::Marshal.decode(raw_element)

          raw_element.children.each {|e| raw_element.delete e}
        when :error
          @state = :error
          raw_element = REXML::Document.new(stanza.to_s).root
          results = @results
          @results = {:error => Vertebra::Conversion::Marshal.decode(raw_element), :results => results}
          @outcall.remove_client(@token)
        when :final
          @results << @partial_data if !@partial_data.empty?

          @state = :commit
          logger.debug "DELETING TOKEN #{@token}"
          @outcall.packet_memory.delete_by_token(@token)
          @outcall.remove_client(@token)
        end

        @last_message_sent = @outcall.send_result(iq.node["from"], iq.node["id"])
      end

      def results
        @results ||= []
        @results.size == 1 ? @results.first : @results
      end

      def done?
        DONE_STATES.include? @state
      end

      def logger
        Vertebra.logger
      end
    end
  end
end
