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
require 'vertebra-gemtool/actor'

include Vertebra

def resource_list(*args)
  args.collect {|a| Vertebra::Resource.new(a)}
end

describe 'Vertebra client' do

  before(:all) do
    throw "ejabberd server must be running" unless EJABBERD.is_running?
    if HERAULT.is_running?
      puts "Detected running herault, using it."
    else
      HERAULT.start
    end

    run_agent('client')
    run_agent('node_agent')
    run_agent('slice_agent')

    @client = DRbObject.new(nil, "druby://localhost:#{CLIENT[:drb_port]}")
    @slice_agent = DRbObject.new(nil, "druby://localhost:#{SLICE_AGENT[:drb_port]}")
    @node_agent = DRbObject.new(nil, "druby://localhost:#{NODE_AGENT[:drb_port]}")
    warm_up do
      @node_agent.clear_queues
    end

    @resources = ['/cluster/rd00', '/slice/0', '/gem']
  end

  before(:each) do
    @client.clear_queues
    @slice_agent.clear_queues
    @node_agent.clear_queues
  end

  after(:all) do
    stop_agent('node_agent')
    stop_agent('slice_agent')
    stop_agent('client')
    HERAULT.stop if HERAULT.started?
  end

  it 'discover agent from herault' do
    warm_up do
      @client.discover '/cluster/rd00', '/slice/0'
    end

    result = @client.discover '/cluster/rd00', '/slice/0'
    result['jids'].first.should == SLICE_AGENT[:jid]
  end

  it 'not discover agents for a non-existent combination of resources' do
    result = @client.discover '/cluster/rd00', '/slice/536'
    result['jids'].should == []
    result = @client.discover '/cluster/ae02', '/node/1'
    result['jids'].should == []
    result = @client.discover '/some/nonexistent/resource'
    result['jids'].should == []
  end

  it 'get a number list from a slice' do
    resources = resource_list('/cluster/rd00', '/slice/0', '/mock')
    results = @client.request('/list/numbers', *resources)
    results.should == [{"response" => [1,2,3]}]
  end

  it 'get number list from slice and node that offer /mock' do
    resources = resource_list('/cluster/rd00', '/mock')
    results = @client.request('/list/numbers', *resources)
    results.should == [{"response"=>[1, 2, 3]}, {"response"=>[1, 2, 3]}]
  end

  it 'get number list from specific slice and give a final result with integer values in the array' do
    result = @client.op('/list/numbers', SLICE_AGENT[:jid], :resource => res('/mock'))
    node = Vertebra::JID.new(SLICE_AGENT[:jid]).node
    result.should == {'response' => [1,2,3]}
  end

  it 'get letter list from a slice' do
    resources = resource_list('/cluster/rd00', '/slice/0', '/mock')
    results = @client.request('/list/letters', *resources)
    results.should == [{"response" => ['a','b','c']}]
  end

  it 'get gem list' do
    expected = VertebraGemtool::Actor.new.list

    resources = resource_list('/cluster/rd00', '/slice/0', '/gem')
    results = @client.request('/gem/list', *resources)
    results.first['response']['result'].should == expected[:result]
  end
end
