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

require 'logger'
require 'fileutils'

module Vertebra
  def self.logger
    unless @logger
      # If the log_path isn't specified in the configuration, default to /tmp/agent.PID
      if Vertebra.config && log_path = Vertebra.config[:log_path]
        case log_path
        when :error
          @logger = Logger.new($stderr)
        end
      else
        "/tmp/agent.#{Process.pid}.log"
      end

      unless @logger
        log_dir = File.dirname(log_path)
        FileUtils.mkdir_p(log_dir) unless File.exists?(log_dir)
        @logger = Logger.new(log_path)
      end
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    end
    @logger
  end
end

module Kernel
  def logger
    Vertebra.logger
  end
end
