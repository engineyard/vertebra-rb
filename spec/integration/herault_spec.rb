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

include Vertebra

describe 'Herault' do

  before(:all) do
    throw "ejabberd server must be running" unless EJABBERD.is_running?

    if HERAULT.is_running?
      puts "Detected running herault, using it."
    else
      HERAULT.start
    end

    run_agent('client')

    @client = DRbObject.new(nil, "druby://localhost:#{CLIENT[:drb_port]}")
  end

  before(:each) do
    @client.clear_queues
  end

  after(:all) do
    stop_agent('client')
    HERAULT.stop if HERAULT.started?
  end

  HERAULT_JID = 'herault@localhost/herault'

  it 'should not be discovered' do
    warm_up do
      @client.discover('/')
    end

    result = @client.discover
    result['jids'].include?(HERAULT_JID).should == false
  end

  it 'should advertise and unadvertise' do
    resource = res("/foo/bar")
    # Make sure herault doesn't have any advertising already there for this resource.
    @client.advertise_op([resource], 0)

    warm_up do
      r = @client.discover('/foo/bar')['jids']
      @client.discover('/foo/bar')['jids'] == []
    end

    @client.discover(resource)['jids'].should == []
    @client.advertise_op([resource])
    @client.discover(resource)['jids'].should == [CLIENT[:jid]]
    @client.advertise_op([resource], 0)
    @client.discover(resource)['jids'].should == []
  end

  it 'should discover all resources' do
    warm_up do
      @client.advertise_op(res('/foo'))
      @client.discover(res('/'))['jids'].size.should == 1
      @client.advertise_op(res('/foo'), 0)
    end
  end

  it 'should expire resources' do
    resource = res("/foo/bar")
    @client.advertise_op([resource], 1)
    sleep(1)
    warm_up do
      @client.discover(resource)['jids'].should == []
    end
  end
end
