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

describe 'Entrepot' do

  before(:all) do
    throw "ejabberd server must be running" unless EJABBERD.is_running?

    if HERAULT.is_running?
      puts "Detected running herault, using it."
    else
      HERAULT.start
    end

    if ENTREPOT.is_running?
      puts "Detected running entrepot, using it."
    else
      ENTREPOT.start
    end

    run_agent('client')

    @client = DRbObject.new(nil, "druby://localhost:#{CLIENT[:drb_port]}")
  end

  before(:each) do
    @client.clear_queues
  end

  after(:all) do
    stop_agent('client')
    ENTREPOT.stop if ENTREPOT.started?
    HERAULT.stop if HERAULT.started?
  end

  ENTREPOT_JID = 'entrepot@localhost/entrepot'

  VALUE1 = {'key' => {'cluster' => res('/cluster/42')},
            'value' => {'foo' => 'bar'}}
  VALUE2 = {'key' => {'cluster' => res('/cluster/42'),
                      'slice' => res('/slice/15')},
            'value' => {'baz' => 'quux'}}

  it 'should discover entrepot' do
    warm_up do
      @client.discover('/entrepot')
    end

    result = @client.discover '/entrepot'
    result['jids'].first.should == ENTREPOT_JID
  end

  it 'should store a value directly' do
    result = @client.op('/entrepot/store', ENTREPOT_JID, VALUE1)
    result.should == VALUE1
  end

  it 'should fetch values' do
    @client.op('/entrepot/store', ENTREPOT_JID, VALUE1)
    @client.op('/entrepot/store', ENTREPOT_JID, VALUE2)
    result = @client.op('/entrepot/fetch', ENTREPOT_JID, 'key' => {'cluster' => res('/cluster/42')})
    result.should == [VALUE1, VALUE2]
  end

  it 'should delete values' do
    @client.op('/entrepot/store', ENTREPOT_JID, VALUE1)
    @client.op('/entrepot/store', ENTREPOT_JID, VALUE2)
    result = @client.op('/entrepot/delete', ENTREPOT_JID, 'key' => VALUE2['key'])
    result.should == VALUE2
    result = @client.op('/entrepot/fetch', ENTREPOT_JID, 'key' => {'cluster' => res('/cluster/42')})
    result.should == VALUE1
  end
end
