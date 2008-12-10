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

    attr_reader :res

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
      resource_number = matchdata[4].to_i

      [new('/cluster/'+cluster_name), new("/#{resource_type}/#{resource_number}")]
    end

    def eql?(other)
      self == other
    end

    def hash
      to_s.hash
    end

    def ==(other)
      @res == other.res
    end

    def <=(other)
      @res[0, other.res.size] == other.res
    end

    def >=(other)
      @res == other.res[0, @res.size]
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

    def initialize(res)
      raise ArgumentError.new("resources *must* start with a / (#{res.inspect})") unless res[0] == ?/
      @res = res[1..-1].split('/')
    end

    def to_s
      "/#{@res.join('/')}"
    end

  end
end



