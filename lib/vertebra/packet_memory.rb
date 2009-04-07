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
  class PacketMemory

    def initialize
      @token_and_id_to_packet = Hash.new {|h1,k1| h1[k1] = {} }
      @jid_and_id_to_packet = Hash.new {|h1,k1| h1[k1] = {} }
    end

    def [](k)
      if @token_and_id_to_packet.has_key?(k)
        @token_and_id_to_packet[k]
      else
        @jid_and_id_to_packet[k]
      end
    end

    def get_by_token(token)
      @token_and_id_to_packet[token]
    end

    def get_by_token_and_id(token, id)
      token_list = @token_and_id_to_packet[token]
      token_list.has_key?(id) ? token_list[id].first : nil
    end

    def get_by_jid(jid)
      @jid_and_id_to_packet[jid]
    end

    def get_by_jid_and_id(jid, id)
      jid_list = @jid_and_id_to_packet[jid]
      jid_list.has_key?(id) ? jid_list[id].first : nil
    end

    def set(jid, token, id, packet)
      @token_and_id_to_packet[token][id] = [packet, jid]
      @jid_and_id_to_packet[jid][id] = [packet, token]
    end

    def delete_by_token(token)
      @token_and_id_to_packet[token].each do |id, tuple|
        @jid_and_id_to_packet.delete(tuple.last)
      end
      @token_and_id_to_packet.delete token
    end

  end
end

