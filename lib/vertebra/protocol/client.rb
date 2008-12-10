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
      attr_reader :state

      def initialize(agent, op, to)
        @agent = agent
        @state = :new
        @to = to
        @op = op
      end

      def make_request
        logger.debug "Client#make_request"
        iq = @op.to_iq(@to, @agent.jid)
        begin
          logger.debug "Client#make_request with #{@agent}"
          @agent.client.send_with_reply(iq) do |answer|
            logger.debug "Client#make_request got answer #{answer}"
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
        rescue Vertebra::JabberError => e
          @result = "Failure; #{e}"
          logger.debug "Client#make_request #{@result}"
          @state = :error
        end
        logger.debug "Client#make_request returning token #{token}"
        token
      end

      def receive(iq)
        logger.debug "Client#recieve state:#{@state} iq:#{iq}"
        case @state
        when :ready
          process_ack_or_nack(iq)
        when :consume
          process_result_or_final(iq)
        end
      end

      def process_ack_or_nack(iq)
        if ack_nack = iq.node.get_child("ack")
          @state = :consume
        elsif ack_nack = iq.node.get_child("nack")
          @result = "Auth Failure; #{ack_nack}"
          @state = :authfail
        end

        result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ)
        result_iq.node.raw_mode = true
        result_iq.node.set_attribute("id", iq.node.get_attribute("id"))
        result_iq.node.set_attribute('xml:lang','en')
        result_iq.node.value = ack_nack
        #result_iq.node.value = ack_nack.to_s.strip
        result_iq.root_node.set_attribute('type', 'result')
        @agent.client.send(result_iq)
      end

      def process_result_or_final(iq)
        logger.debug "Client#process_result_or_final: #{iq}"
        result_iq = nil
        
        if ele = iq.node.get_child('result')
          raw_ele = REXML::Document.new(ele.to_s).root
          (@results ||= []) << Vertebra::Marshal.decode(raw_ele)
          raw_ele.children.each{|e| raw_ele.delete(e)}
        elsif ele = iq.node.get_child('final')
          @state = :commit
          @agent.clients.delete(token)
        end
        
        # 
        # if iq.node.name == 'result'
        #   (@results ||= []) << Vertebra::Marshal.decode(ele)
        #   ele.children.each{|e| ele.delete(e)}
        # elsif iq.node.name == 'final'
        #   @state = :commit
        #   @agent.clients.delete(token)
        # end

        result_iq = LM::Message.new(iq.node.get_attribute("from"), LM::MessageType::IQ, LM::MessageSubType::RESULT)
        result_iq.node.raw_mode = true
        result_iq.node.set_attribute('id', iq.node.get_attribute('id'))
        result_iq.node.value = ele.to_s
        result_iq.node.set_attribute('type', 'result')
        @agent.client.send(result_iq)
      end

      def results
        @results ||= []
        @results.size == 1 ? @results.first : @results
      end

      def done?
        DONE_STATES.include? @state
      end

    end  # Client

  end  # Protocol
end  # Vertebra
