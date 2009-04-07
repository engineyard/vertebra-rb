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

require 'date'

module Vertebra
  class DateTime

    attr_reader :year, :month, :day, :hour, :min, :sec

    def year=(value)
      raise ArgumentError, "date/time out of range" unless value.is_a? Integer
      @year = value
    end

    def month=(value)
      raise ArgumentError, "date/time out of range" unless (1..12).include? value
      @month = value
    end

    def day=(value)
      raise ArgumentError, "date/time out of range" unless (1..31).include? value
      @day = value
    end

    def hour=(value)
      raise ArgumentError, "date/time out of range" unless (0..24).include? value
      @hour = value
    end

    def min=(value)
      raise ArgumentError, "date/time out of range" unless (0..59).include? value
      @min = value
    end

    def sec=(value)
      raise ArgumentError, "date/time out of range" unless (0..59).include? value
      @sec = value
    end

    alias mon  month

    # This should be initialized with a UTC time.

    def initialize(year, month, day, hour, min, sec)
      self.year, self.month, self.day = year, month, day
      self.hour, self.min, self.sec   = hour, min, sec
    end

    def to_time
      if @year >= 1970
        Time.gm(*to_a)
      else
        nil
      end
    end

    def to_date
      Date.new(*to_a[0,3])
    end

    def to_a
      [@year, @month, @day, @hour, @min, @sec]
    end

    def ==(o)
      Array(self) == Array(o)
    end

  end
end
