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
  class ClientAPI
    attr_accessor :handle

    def initialize(handle)
      @handle = handle
    end

    def request(*args, &block)
      discoverer = @handle.request(*args)
      until (discoverer.has_key?(:results))
        sleep 0.05
      end
      if block_given?
        yield discoverer[:results]
      else
        discoverer[:results]
      end
    end
  end
end
