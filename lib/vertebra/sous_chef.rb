# Copyright 2009, Engine Yard, Inc.
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

module Vertebra
  class SousChef
    class Entree
      attr_reader :args, :jids, :resources, :scope

      def initialize(scope, jids, args, resources)
        @scope, @jids, @args, @resources = scope, jids, args, resources
      end
    end

    class << self
      def prepare(*raw)
        ingredients = raw.dup
        scope = prepare_scope(ingredients)
        args, jids = *prepare_args(ingredients)
        resources = extract_resources(args)
        Entree.new(scope, jids, args, resources)
      end

      def extract_resources(item)
        case item
        when Vertebra::Resource then
          [item]

        when Hash then
          result = []
          item.each_value {|value| result += extract_resources(value)}
          result

        when Array then
          item.inject([]) {|result, val| result + extract_resources(val)}

        else
          []
        end
      end

      PAIR_REGEXP = /^([^=]+)=(.+)/
      JID_REGEXP = /^jid:(.*)/

      def prepare_args(ingredients)
        args = {}
        jids = []
        ingredients.each do |item|
          case item
          when Hash
            args.merge! item
          when JID_REGEXP
            jids << $1
          when PAIR_REGEXP
            args[$1] = $2
          else
            args[item] = Vertebra::Utils.resource(item)
          end
        end
        [args, jids]
      end

      def prepare_scope(ingredients)
        Symbol === ingredients.first ? ingredients.shift : :all
      end
    end
  end
end
