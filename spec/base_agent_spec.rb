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
require 'vertebra/base_agent'

describe "An instance of Vertebra::BaseAgent" do

  before(:all) do
    @jid = 'test@example.com'
    @password = 'test'
  end

  it 'should raise ArgumentError when initialized without a jid or password' do
    lambda { Vertebra::BaseAgent.new(nil, @password) }.should raise_error(ArgumentError)
    lambda { Vertebra::BaseAgent.new(@jid, nil) }.should raise_error(ArgumentError)
  end

  it 'should setup pid file when background option is not present' do
    mock(Vertebra::Daemon).setup_pidfile
    Vertebra::BaseAgent.new(@jid, @password)
  end

  it 'should set instance variables from options' do
    agent = Vertebra::BaseAgent.new(@jid, @password, {:drb_port => 1234, :jabber_debug => true})
    #Jabber.debug.should == true
    agent.drb_port.should == 1234
    agent.jid.should be_a_kind_of(Vertebra::JID)
  end

  it 'should connect, add default callbacks, open a DRb port and start event loop' do
    agent = Vertebra::BaseAgent.new(@jid, @password, {:drb_port => 1234, :use_drb => true})
    mock(agent).connect!

    # Yeah, this is kind of gross.  Add #run as a synonym for #call on a Proc, and use
    # that as a simple mock for the GLib element in @main_loop.

    class Proc
      alias :run :call
    end

    fake_main_loop = lambda {}
    agent.instance_variable_set('@main_loop',fake_main_loop)

    agent.start
  end


end
