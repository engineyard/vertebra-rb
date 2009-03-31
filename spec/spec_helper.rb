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

$TESTING = true

require 'rubygems'
require 'pp'
require 'drb'
require 'yaml'
require 'rr'
require 'spec'
require File.dirname(__FILE__) + '/../lib/vertebra'

Spec::Runner.configure do |config|
   config.mock_with :rr
   # or if that doesn't work due to a version incompatibility
   # config.mock_with RR::Adapters::Rspec
 end
