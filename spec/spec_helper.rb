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
require 'rr'
require 'spec'
require File.dirname(__FILE__) + '/../lib/vertebra'

Spec::Runner.configure do |config|
  config.mock_with :rr
  # or if that doesn't work due to a version incompatibility
  # config.mock_with RR::Adapters::Rspec
end

Spec::Matchers.create :provide_operations do |operations|
  match do |actor|
    @actual = normalize(actor.provided_operations)
    @actual == operations
  end

  failure_message_for_should do |actor|
    "The Actor was expected to provide the operations: #{operations.inspect}, but got #{@actual.inspect}"
  end

  def normalize(operations)
    operations.map {|operation|
      operation.to_s
    }.sort
  end
end

Spec::Matchers.create :provide_resources do |resources|
  match do |actor|
    @actual = normalize(actor.provided_resources)
    @actual == resources
  end

  failure_message_for_should do |actor|
    "The Actor was expected to provide the resources: #{resources.inspect}, but got #{@actual.inspect}"
  end

  def normalize(resources)
    data = {}
    resources.each do |key,resources|
      resources = resources.map do |resource|
        resource.to_s
      end
      data[key.to_s] = resources.sort
    end
    data
  end
end
