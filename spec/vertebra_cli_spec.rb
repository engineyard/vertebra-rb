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
require 'vertebra/vertebra_cli'
require 'tempfile'
require 'stringio'

describe Vertebra do
  it "can disable the logger" do
    Vertebra::disable_logging
    
    logger = Vertebra.class_eval('@@logger')
    Vertebra::SwallowEverything.should === logger
  end
end

describe Vertebra::SwallowEverything do
  it "swallows anything and everything called on it" do
    swallower = Vertebra::SwallowEverything.new
    swallower.abc.should == nil
    swallower.moon(:a).should == nil
    swallower.lycat([1,2,3,4]).should == nil
  end
end

describe Vertebra::VertebraCLI do
  it "self.dispatch_request" do
    # TODO: Implement reasonable tests of the dispatching.
  end

  it "self.show_results" do
    orig_stdout = $stdout
    captured_stdout = StringIO.new
    $stdout = captured_stdout
    # TODO: finish writing the test for this.
    $stdout = orig_stdout
  end
  
  it "self.run" do
    # TODO: write a test for this method.
  end
  
  it "self.keys_to_symbols" do
    hash = {'abc' => 123, :def => 456}
    newhash = Vertebra::VertebraCLI.__send__(:keys_to_symbols,hash)
    newhash[:def].should == 456
    newhash['abc'].should == nil
    newhash[:abc].should == 123
  end
end
