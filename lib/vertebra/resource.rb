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

    attr_reader :parts

    def self.parse_hostname(hostname)
      return false if hostname.nil?
      matchdata = hostname.match(/([a-z]+)(\d+)-([a-z]+)(\d+)/)
      return false if matchdata.nil? || matchdata.size != 5
      cluster_name = matchdata[1] + matchdata[2]

      resource_type = case matchdata[3]
      when 's'; "slice"
      when 'n'; "node"
      when 'gw'; "gateway"
      end
      resource_number = matchdata[4].to_iparts

      [new('/cluster/'+cluster_name), new("/#{resource_type}/#{resource_number}")]
    end

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

    # The assumptions in these comparisons are:
    #   1) shorter resources are greater than longer resources
    #   2) resources of equal length are compared lexigraphically
    
    def ==(other)
      @parts == other.parts
    end

    def <=(other)
      if @parts.size == other.parts.size
        (@parts <=> other.parts) < 1 ? true : false # @parts <= other.parts
      else
        @parts.size > other.parts.size
      end 
    end

    def >=(other)
      if @parts.size == other.parts.size
        (@parts <=> other.parts) > -1 ? true : false # @parts >= other.parts
      else
        @parts.size < other.parts.size
      end
    end

    def <(other)
      not self >= other
    end

    def >(other)
      not self <= other
    end

    def <=>(other)
      if self < other then -1
      elsif self > other then 1
      else 0 end
    end

    def [](index)
      @parts[index]
    end

    def initialize(resource)
      res_string = resource.to_s # This lets one pass a Vertebra::Resource in, and get a copy of it instead of an error.
      raise ArgumentError, "#{res_string.inspect} does not start with a / ()" unless res_string[0] == ?/
      @parts = res_string[1..-1].split('/')
    end

    def to_s
      ["", @parts].join('/')
    end

  end
end



