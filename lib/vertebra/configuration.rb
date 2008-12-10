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
  class Configuration
      attr_accessor :path

    def initialize(path)
      @config = YAML.load(File.read(path))
      @file = File.open(path, "w")
    end

    def [](key)
      key = key.to_s
      @config[key]
    end

    def []=(key, value)
      key = key.to_s
      @config[key] = value
    end

    def push(key, value)
      key = key.to_s
      if !@config[key].respond_to?(:push)
        raise ArgumentError, "#{key} is not an array"
      elsif @config[key].include?(value)
        raise ArgumentError, "Value '#{value}' already exists in '#{key}'"
      else
        @config[key].push value
      end
    end

    def reload
      read
    end

    private

    def read
      @config = YAML.load(File.read(path))
    end

  end
end
