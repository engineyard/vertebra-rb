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

  class Base64

    def initialize(str, state = :dec)
      case state
      when :enc
        @str = Base64.decode(str.to_s)
      when :dec
        @str = str.to_s
      else
        raise ArgumentError, "wrong argument; either :enc or :dec"
      end
    end

    def decoded
      @str
    end

    def encoded
      Base64.encode(@str)
    end


    def self.decode(str)
      str.to_s.gsub(/\s+/, "").unpack("m")[0]
    end

    def self.encode(str)
      [str.to_s].pack("m")
    end

  end

end # module Vertebra
