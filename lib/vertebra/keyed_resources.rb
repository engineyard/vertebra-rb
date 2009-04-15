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
require 'vertebra/resource'

module Vertebra
  class KeyedResources
    class ResourceSet
      include Enumerable

      def initialize
        @set = Set.new
      end

      def add(resource)
        @set << Vertebra::Resource.parse(resource)
      end

      def matches?(resource)
        @set.any? do |provided|
          provided >= resource || resource >= provided
        end
      end

      def each(&block)
        @set.each(&block)
      end

      def to_a
        @set.to_a
      end
    end

    include Enumerable

    def initialize
      @entries = {}
    end

    def add(key, resource)
      @entries[key] ||= ResourceSet.new
      @entries[key].add(resource)
    end

    def matches?(key, resource)
      if entries = @entries[key]
        entries.matches?(resource)
      end
    end

    def merge(other)
      other.each do |key,resources|
        resources.each do |resource|
          add(key, resource)
        end
      end
    end

    def +(other)
      merged = KeyedResources.new
      merged.merge(self)
      merged.merge(other)
      merged
    end

    def each(&block)
      @entries.each(&block)
    end

    def to_hash
      data = {}
      @entries.each do |key,value|
        data[key] = value.to_a
      end
      data
    end
  end
end
