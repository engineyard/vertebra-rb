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
    # The server follows a simple progression as well.
    #
    # Verify
    # Producing
    # Flush
    # Commit
    # When the request is received, verification is done. Depending on the operation, this might be different things. An Acknowledgement or Negative Acknowledgement is sent and the reply triggers movement into the Producing state.
    #
    # In the Producing state, "result" stanzas are sent in rapid succession. When no more results will be generated, the Flush state is entered.
    #
    # In the Flush state, any outstanding "result" confirmations are collected.
    #
    # In the Commit state, the "final" stanza is sent, effectively signaling that the sender is finished.

    class Herault

      attr_accessor :token, :agent, :state

      def initialize(agent)
        @agent = agent
        @state = :new
      end

      def receive_request(iq)
        logger.debug "Herault#receive_request#{iq}"
        @iq = Vertebra.deep_copy(iq)
        @op = Vertebra.deep_copy(iq.first_element('op'))
        op = iq.first_element('op')
        self.token = op.attributes['token'].split(':').last << ":#{Vertebra.gen_token}"
        op.token = token
        result_iq = Jabber::XMPPStanza.answer(iq, false)
        result_iq.type = :result
        result_iq.add op
        Thread.new { @agent.client.send(result_iq) }
        @state = :verify
        process_ack
      end

      def process_ack
        logger.debug "Herault#process_authorized"
        iq = Jabber::Iq.new(:set, @iq.from)
        ack = Vertebra::Ack.new(token)
        iq.add(ack)
        begin
          @agent.client.send_with_id(iq) do |answer|
            logger.debug "answer #{answer}"
            if answer.type == :result
              process_operation
            else
              process_terminate
            end
          end
        rescue Jabber::JabberError
          process_terminate
        end

      end

      def process_operation
        @state = :producing
        logger.debug "Herault#process_operation: #{@op}"
        begin
          result_iq = Jabber::Iq.new(:set, @iq.from)
          result_iq.from = @agent.jid
          result_tag = Vertebra::Result.new(token)


          if @op.attributes['type'] == 'discover'
            logger.debug "DISCOVERY #{@op}"
            jids = @agent.handle_discovery(@op)
            result_iq.type = :set
            Vertebra::Marshal.encode({'jids' => jids}).children.each do |el|
              result_tag.add(el)
            end
            result_iq.add(result_tag)
          end

          if @op.attributes['type'] == 'advertise'
            logger.debug "ADVERTISE #{@op}"
            @agent.handle_advertise(@iq.from, @op)
            result_iq = nil
          end

          if @op.attributes['type'] == 'authorize'
            logger.debug "AUTHORIZE? #{@op}"

            if @agent.authorized?(@op)
              result_iq.type = :set
              Vertebra::Marshal.encode({'response' => 'authorized'}).children.each do |el|
                result_tag.add(el)
              end
              result_iq.add(result_tag)
            else
              result_iq.type = :set
              Vertebra::Marshal.encode({'response' => 'notauthorized'}).children.each do |el|
                result_tag.add(el)
              end
              result_iq.add(result_tag)
            end
          end

          send_result(result_iq, token) if result_iq
          send_final(token)

        rescue Exception => e
          logger.error Vertebra.exception(e)
          logger.error "operation FAILED #{op}"
          result_tag = Vertebra::Result.new(token)
          result_tag.attributes['status'] = 'error'
          Vertebra::Marshal.encode({:backtrace => Vertebra.exception(e)}).children.each do |ch|
            result_tag.add(ch)
          end
          result_iq = Jabber::Iq.new(:set, @iq.from)
          result_iq.type = :set
          result_iq.add(result_tag)
          @agent.client.send_with_id(result_iq) do |answer|
            @state = :error
          end
        end
      end

      def process_terminate
        logger.debug "terminating op!:#{@op}"
        true
      end

      def send_final(token)
        final_iq = Jabber::Iq.new(:set, @iq.from)
        final_iq.from = @jid
        final_tag = ::Vertebra::Final.new(token)
        final_iq.add(final_tag)
        @agent.client.send_with_id(final_iq) do |answer|
          if answer.type == :result
            @state = :commit
          end
        end
      end

      def send_result(result_iq, token)
        @agent.client.send_with_id(result_iq) do |answer|
          if answer.type == :result
            @state = :flush
          end
        end
      end
    end

  end # Protocol

end # Vertebra
