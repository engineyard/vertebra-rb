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

$:.unshift File.dirname(__FILE__)

require File.dirname(__FILE__) + '/../vendor/thor/lib/thor'

require 'drb'
require 'pp'
require 'yaml'
require 'logger'
require 'conversion'

require 'rubygems'
require 'vertebra/xmppelement'
require 'vertebra/jid'

require 'loudmouth'
require 'vertebra/loudmouth_extension'
require 'eventmachine'
require 'vertebra/protocol/client'
require 'vertebra/protocol/server'
require 'vertebra/logger'
require 'vertebra/extensions'
require 'vertebra/dispatcher'
require 'vertebra/resource'
require 'vertebra/daemon'
require 'vertebra/elements'
require 'vertebra/sous_chef'
require 'vertebra/outcall'

module Vertebra

  class JabberError < StandardError; end

  # ==== Returns
  # String:: A random 32 character string for use as a unique ID.
  def self.gen_token
    values = [
      rand(0x0010000),
      rand(0x0010000),
      rand(0x0010000),
      rand(0x0010000),
      rand(0x0010000),
      rand(0x1000000),
      rand(0x1000000),
    ]
    "%04x%04x%04x%04x%04x%06x%06x" % values
  end

  def self.deep_copy(obj)
    ::Marshal.load(::Marshal.dump(obj))
  end

end
