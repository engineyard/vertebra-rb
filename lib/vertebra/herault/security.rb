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

require 'vertebra/herault/advert_cache'

module Vertebra
  module Herault
    class Security < Vertebra::Actor
      bind_op "/security/advertise", :advertise
      desc "/security/advertise", "Store a resource advertisement"
      def advertise(operation, options)
        ttl = options["ttl"]
        options["resources"].each do |resource|
          advert_cache.add(resource, operation.from, ttl.to_i)
        end
        puts "Resources: "
        puts advert_cache.resources
        true
      end

      bind_op "/security/discover", :discover
      desc "/security/discover", "Discover agents for an operation"
      def discover(operation, options)
        jids = advert_cache.search(options["resources"]["type"])

        options["resources"]["args"].each do |key,resource|
          jids &= advert_cache.search(resource)
        end

        {"jids" => jids}
      end

      bind_op "/security/authorize", :authorize
      desc "/security/authorize", "Authorize an operation"
      def authorize(operation, options)
        'authorized'
      end

      def advert_cache
        @advert_cache ||= AdvertCache.new
      end
    end
  end
end
