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
require 'vertebra/cli/main'

describe Vertebra::SwallowEverything do
  it "swallows anything and everything called on it" do
    swallower = Vertebra::SwallowEverything.new
    swallower.abc.should == nil
    swallower.moon(:a).should == nil
    swallower.lycat([1,2,3,4]).should == nil
  end
end

describe Vertebra::CLI::Main do
  it "#dispatch_request" do
    pending "not implemented"
  end

  it "#show_results" do
    pending "not implemented"
  end

  it "#run" do
    pending "not implemented"
  end
end
