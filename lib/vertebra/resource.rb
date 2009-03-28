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
  class Resource
    def self.parse(text)
      # This lets one pass a Vertebra::Resource in, and get a copy of it instead of an error.
      res_string = text.to_s
      raise ArgumentError, "#{res_string.inspect} does not start with a / ()" unless res_string[0] == ?/
      new(res_string[1..-1].split('/'))
    end

    def initialize(parts)
      raise ArgumentError, "#{parts.inspect} is not an Array" unless parts.is_a?(Array)
      @parts = parts
    end
    attr_reader :parts

    def first
      @parts.first
    end

    def last
      @parts.last
    end

    def size
      (@parts || []).size
    end

    def eql?(other)
      self == other
    end

    def hash
      to_s.hash
    end

    def ==(other)
      @parts == other.parts
    end

    def <=(other)
      @parts[0, other.size] == other.parts
    end

    def >=(other)
      other.parts[0, size] == @parts
    end

    def <(other)
      other >= self[0..-2]
    end

    def >(other)
      other[0..-2] <= self
    end

    def <=>(other)
      if self < other then -1
      elsif self > other then 1
      elsif self == other then 0
      else raise(ArgumentError, "#{self.inspect} and #{other.inspect} cannot be compared")
      end
    end

    def [](*args)
      Resource.new(@parts[*args])
    end

    def to_s
      ["", @parts].join('/')
    end

    def inspect
      "#<#{self.class} #{to_s.inspect}>"
    end
  end
end
