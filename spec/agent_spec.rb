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

describe "An instance of Vertebra::Agent" do

  before(:all) do
    @jid = 'test@example.com'
    @password = 'test'
  end

  it "instantiates an instance of Agent" do
    agent = Vertebra::Agent.new(@jid, @password)
  end

  it "populates jid as expected" do
    agent = Vertebra::Agent.new(@jid, @password)
    agent.jid.to_s.should == 'test@example.com/agent'

    agent = Vertebra::Agent.new("#{@jid}/secretagent", @password)
    agent.jid.to_s.should == 'test@example.com/secretagent'
  end

end
