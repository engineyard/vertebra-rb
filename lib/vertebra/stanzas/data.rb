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
    class Data < Stanza
      def handle_set
        if client = agent.clients[token]
          agent.packet_memory.set(to, token, id, iq)
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = client
          result_handler[:state] = :result
          result_handler.callback do
            logger.debug "data"
            client.process_data_or_final(iq, :result, child_node)
          end
          agent.enqueue_synapse(result_handler)
        else
          logger.warn "No client found with token: #{token.inspect}"
        end
      end

      def handle_result
        if server = agent.servers[token]
          result_handler = Vertebra::Synapse.new
          result_handler[:client] = server
          result_handler[:state] = :result
          result_handler.callback do
            logger.debug "data"
            server.process_data_result(node)
          end
          agent.enqueue_synapse(result_handler)
        else
          logger.warn "No server found with token: #{token.inspect}"
        end
      end
    end
  end
end
