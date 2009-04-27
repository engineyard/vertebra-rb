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
    class Init < Stanza
      def handle_set
        agent.packet_memory.set(to, token, id, iq)
        # The protocol object will take care of enqueing itself.
        logger.debug "Creating server protocol for token: #{token.inspect}"
        Vertebra::Protocol::Server.new(agent, iq)
      end

      def handle_result
        logger.debug "Got token: #{token.inspect}"
        left, right = token.split(':',2)
        jid_plus_id = "#{iq.node['from']};#{iq.node['id']}"
        if client = agent.clients[jid_plus_id]
          agent.clients[token] = client
          agent.clients.delete(jid_plus_id)
          client.is_ready(token)
        else
          logger.warn "No client found with token: #{left.inspect}"
        end
      end
    end
  end
end
