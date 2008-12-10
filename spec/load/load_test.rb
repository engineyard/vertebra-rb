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

require File.dirname(__FILE__) + '/../spec_helper'
require 'vertebra/agent'
require 'pp'
require 'benchmark'

include Vertebra

describe 'Vertebra client' do

  before(:all) do
    run_agent('ey_client')
    sleep 8

    @client = DRbObject.new(nil, "druby://localhost:#{CLIENT[:drb_port]}")
  end

  after(:all) do
    stop_agent('ey_client')
  end

  it 'should discover all ey05 nodes' do
    response = @client.discover '/cluster/ey05'
    response['jids'].size.should == 18
  end

  it 'should discover and query each ey05 node separately' do

    0.upto(18) do |node|
      puts "Requesting on node #{node}"
      response = @client.broadcast 'list', '/cluster/ey05', "/node/#{node}", "/gem"
      response = @client.broadcast 'list', '/cluster/ey05', "/node/#{node}", "/gem"
      response.should be_a_kind_of(Hash)
    end
  end

  it 'should retrieve gem list results from all ey05 nodes' do
    response = @client.broadcast 'list', '/cluster/ey05', '/gem'
    response.size.should == 18
  end

  it 'should retrieve xen list results from all ey05 nodes' do
    response = @client.broadcast 'list', '/cluster/ey05', '/xen'
    response.size.should == 18
  end

  it 'should retrieve xen info results from all ey05 nodes' do
    response = @client.broadcast 'info', '/cluster/ey05', '/xen'
    response.size.should == 18
  end

end
