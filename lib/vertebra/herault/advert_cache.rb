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

require 'set'

module Vertebra
  module Herault
    class AdvertCache
      def initialize
        @entries = Hash.new {|h,k| h[k] = {}}
      end

      def add(resource, from, ttl)
        @entries[resource][from] = Time.now + ttl
      end

      def resources
        @entries.keys
      end

      def search(resource)
        jids = Set.new
        @entries.each do |key,entry|
          if key >= resource || resource >= key
            entry.each do |jid,ttl|
              jids << jid if Time.now < ttl
            end
          end
        end
        jids
      end

      def jids
        search(Vertebra::Utils.resource('/'))
      end
    end
  end
end
