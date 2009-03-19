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

require 'vertebra/resource'
require 'loudmouth'

module Vertebra
  class ClientAPI
    attr_accessor :handle

    def initialize(handle)
      @handle = handle
    end

    def direct_op(op_type, to, *args)
      @handle.direct_op(op_type, to, *args)
    end

    def op(op_type, to, *args)
      client = direct_op(op_type, to, *args)
      while !(z = client.done?)
        sleep 0.05
      end
      client.results
    end

    def request(op_type, *raw_args)
      discoverer = @handle.request(op_type, *raw_args)
      until (discoverer.has_key?(:results))
        sleep 0.05
      end
      discoverer[:results]
    end

    def advertise_op(resources, ttl = @handle.ttl)
      client = @handle.advertise_op(resources,ttl)

      while !(z = client.done?)
        sleep 0.05
      end
    end

    def unadvertise_op(resources)
      advertise_op(resources,0)
    end

    def send_packet(*args)
      @handle.send_packet(*args)
    end
    
    def send_packet_with_reply(*args)
      @handle.send_packet_with_reply(*args)
    end

  end
end
