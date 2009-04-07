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
      bind_op "/security/advertise"
      desc "Store a resource advertisement"
      def advertise(args, job)
        ttl = args["ttl"]

        args["operations"].each do |operation|
          operation_advert_cache.add(operation, job.from, ttl.to_i)
        end

        args["resources"].each do |key,resources|
          resources.each do |resource|
            advert_cache_for(key).add(resource, job.from, ttl.to_i)
          end
        end

        puts "Operations cache: "
        puts operation_advert_cache.resources

        advert_caches.each do |key,cache|
          puts "Resources for #{key.inspect}: "
          puts cache.resources
        end

        true
      end

      bind_op "/security/discover"
      desc "Discover agents for an operation"
      def discover(args, job)
        pp ["operation", "search", args["job"]["operation"]]
        jids = operation_advert_cache.search(args["job"]["operation"])
        pp ["operation", "results", jids]

        args["job"]["resources"].each do |key,resource|
          pp ["resource", "search", key, resource]
          pp advert_cache_for(key)
          jids &= advert_cache_for(key).search(resource)
          pp ["resource", "results", key, jids]
        end

        {"jids" => jids}
      end

      bind_op "/security/authorize"
      desc "Authorize an operation"
      def authorize(operation, options)
        'authorized'
      end

      def operation_advert_cache
        @operation_advert_cache ||= AdvertCache.new
      end

      def advert_cache_for(key)
        advert_caches[key.to_s] ||= AdvertCache.new
      end

      def advert_caches
        @advert_caches ||= {}
      end
    end
  end
end
