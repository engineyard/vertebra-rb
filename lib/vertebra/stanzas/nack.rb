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
  module Stanzas
    class Nack < Stanza
      def handle_set
        if client = agent.clients[token]
          agent.deja_vu_map[token][id] = iq
          nack_handler = Vertebra::Synapse.new
          nack_handler[:client] = client
          nack_handler[:state] = :nack
          nack_handler.callback do
            logger.debug "nack"
            client.process_ack_or_nack(iq, :nack, child_node)
          end
          agent.enqueue_synapse(nack_handler)
        else
          logger.warn "No client found with token: #{token.inspect}"
        end
      end

      def handle_result
        if server = agent.servers[token]
          ack_handler = Vertebra::Synapse.new
          ack_handler[:client] = server
          ack_handler[:state] = :nack
          ack_handler.callback do
            logger.debug "nack"
            server.process_nack_result
          end
          agent.enqueue_synapse(ack_handler)
        else
          logger.warn "No server found with token: #{token.inspect}"
        end
      end
    end
  end
end
