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
require 'vertebra'

require 'vertebra/actors/core'

describe Vertebra::Actors::Core do
  
  before(:all) do
    @actor = Vertebra::Actors::Core.new
  end
  
  it 'should provide /core resource' do
    @actor.provides.should == [Vertebra::Resource.new('/core')]
  end

  it 'should exit process in quit method' do
    mock(Thread).new
    # TODO: mock exit! call
    result = @actor.quit
    result.should == "Restarting agent"
  end

end
