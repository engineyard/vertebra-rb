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

require File.dirname(__FILE__) + '/spec_helper'
require 'vertebra'
require 'vertebra/agent'
require 'vertebra/synapse_queue'

# Specs to test the protocol portion of Vertebra.

describe Vertebra::Op do

  it 'should allow initialization with an array' do
    op = Vertebra::Op.new('/testop',"/test/test")
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['/test/test'].should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@args')['/test/test'].to_s.should == '/test/test'
  end

  it 'should allow initialization with a hash' do
    op = Vertebra::Op.new('/testop',{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['from'].should == '/george'
    op.instance_variable_get('@args')['to'].should == '/man/in/yellow/hat'
  end

  it 'should allow initialization with an array and a hash' do
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['/test/test'].should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@args')['/test/test'].to_s.should == '/test/test'
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['from'].should == '/george'
    op.instance_variable_get('@args')['to'].should == '/man/in/yellow/hat'
  end

  # todo: write a decent test of #to_iq

end

class Mock
  def initialize
    @handlers = {}
  end

  def add_handler(symbol, &block)
    @handlers[symbol] = block
  end

  def remove_handler(symbol)
    @handlers.delete(symbol)
  end

  def method_missing(symbol, *args)
    method = @handlers[symbol]
    unless method.nil?
      method.call(*args)
    else
      super
    end
  end
end

class MockAgent < Mock
  def enqueue_synapse(synapse)
    synapses << synapse
  end

  def synapses
    @synapses ||= Vertebra::SynapseQueue.new
  end
end

describe Vertebra::Protocol::Client do

  before :all do
    @agent = MockAgent.new
    @op = Vertebra::Op.new("/foo")
    @to = nil
    @client = Vertebra::Protocol::Client.new(@agent, @op, @to)
  end

  it 'Should enqueue a synapse during initialization' do
    @client.state.should == :new
    @agent.synapses.size.should == 1
  end

  it 'Should check connection status and defer if jid is busy' do
    synapse = @agent.synapses.first

    # Both return false
    @agent.add_handler(:connection_is_open_and_authenticated?) {:deferred}
    @agent.add_handler(:defer_on_busy_jid?) {|jid| :deferred}
    @agent.synapses.fire
    @agent.synapses.size.should == 1
    @agent.synapses.first.should == synapse

    # Connection returns true
    @agent.add_handler(:connection_is_open_and_authenticated?) {true}
    @agent.synapses.fire
    @agent.synapses.first.should == synapse
  end
end

describe Vertebra::Protocol::Server do

end
