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

      attr_reader :state, :to

      def self.start(agent, op, to)
        new(agent, op, to).start
      end

      def initialize(agent, op, to)
        @agent = agent
        @state = :new
        @to = to
        @op = op
      end

      def start
        initiator = Vertebra::Synapse.new
        initiator[:name] = 'initiator'
        initiator.condition { @agent.connection_is_open_and_authenticated? }
        # TODO: The logic that deals with this can be messed up, somehow.  Debug it.
        initiator.condition { @agent.defer_on_busy_jid?(@to) }
        initiator.callback do
					logger.debug("setting busy jid #{@to}")
          @agent.set_busy_jid(@to,self)
          make_request
        end

        @agent.enqueue_synapse(initiator)
        self
      end

      def make_request
        requestor = Vertebra::Synapse.new
        requestor[:name] = 'requestor'
        iq = @op.to_iq(@to, @agent.jid)
        @agent.add_client(@op.token, self)
        logger.debug "Assigning client to token #{@op.token}"
        requestor.condition {@agent.connection_is_open_and_authenticated?}
        requestor.callback do
          logger.debug "in requestor callback"
          @last_message_sent = iq
          @agent.send_iq(iq)
        end
        @agent.enqueue_synapse(requestor)
      end

      def is_ready
        @state = :ready
      end

      def resend
        delay = @last_message_sent.node['retry_delay'].to_i || 0
        delay += 1
        @last_message_sent.node['retry_delay'] = delay.to_s
        logger.debug "Resending #{@last_message_sent.node}"
        resender = Vertebra::Synapse.new
        resender.condition { @agent.connection_is_open_and_authenticated? }
        resender.callback do
          @agent.send_iq(@last_message_sent)
        end
        EM.add_timer((Math.log(delay + 0.1)).to_i) { @agent.enqueue_synapse(resender) }
      end

      def process_ack_or_nack(iq, stanza_type, stanza)
        #TODO: Add state checking code so that we don't get messed up by
        #unexpected stanzas.

        logger.debug "Client#process_ack_or_nack: #{iq.node}"
        case stanza_type
        when :ack
          @state = :consume
        when :nack
          @result = "Auth Failure; #{stanza}"
          @state = :authfail
        end

        result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ)
        result_iq.node.raw_mode = true
        result_iq.node.set_attribute("id", iq.node.get_attribute("id"))
        result_iq.node.set_attribute('xml:lang','en')
        result_iq.node.value = stanza
        result_iq.root_node.set_attribute('type', 'result')

        response = Vertebra::Synapse.new
        response[:name] = 'process_ack_or_nack response'
        response.condition { @agent.connection_is_open_and_authenticated? }
        response.callback do
          logger.debug "Client#process_ack_or_nack: sending #{result_iq.node}"
          @last_message_sent = result_iq
          @agent.send_iq(result_iq)
        end

        @agent.enqueue_synapse(response)
      end

      def process_data_or_final(iq, stanza_type, stanza)
        logger.debug "Client#process_data_or_final: #{iq.node}"
        case stanza_type
        when :result
          raw_element = REXML::Document.new(stanza.to_s).root
          (@results ||= []) << Vertebra::Marshal.decode(raw_element)
          raw_element.children.each {|e| raw_element.delete e}
        when :error
          @state = :error
          raw_element = REXML::Document.new(stanza.to_s).root
          results = @results
          @results = {:error => Vertebra::Marshal.decode(raw_element), :results => results}
          @agent.remove_client(@agent.parse_token(iq.node.find_child('error')))
        when :final
          @state = :commit
          logger.debug "DELETING TOKEN #{@agent.parse_token(iq.node.find_child('final'))}"
          @agent.deja_vu_map.delete(iq.node['token'])
          @agent.remove_client(@agent.parse_token(iq.node.find_child('final')))
        end

        result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ, LM::MessageSubType::RESULT)
        result_iq.node.raw_mode = true
        result_iq.node.set_attribute('id', iq.node.get_attribute('id'))
        result_iq.node.value = stanza
        result_iq.node.set_attribute('xml:lang','en')
        result_iq.node.set_attribute('type', 'result')
        response = Vertebra::Synapse.new
        response[:name] = 'process_data_or_final response'
        response.condition { @agent.connection_is_open_and_authenticated? }
        response.callback do
          logger.debug "Client#process_data_or_final: sending #{result_iq.node}"
          @last_message_sent = result_iq
          @agent.send_iq(result_iq)
          if [:final, :error].include?(stanza_type)
            @agent.remove_busy_jid(@to,self)
          end
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

      def logger
        Vertebra.logger
      end
    end
  end
end
