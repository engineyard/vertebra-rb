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
    class Error < Stanza
      def handle_result
        if server = agent.servers[token]
          error_handler = Vertebra::Synapse.new
          error_handler[:client] = server
          error_handler[:state] = :error
          error_handler.callback do
            logger.debug "error"
            agent.servers.delete(token)
            server.process_error
          end
          agent.enqueue_synapse(error_handler)
        else
          logger.warn "No server found with token: #{token.inspect}"
        end
      end
    end
  end
end
