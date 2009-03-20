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
require 'vertebra/extensions.rb'

describe 'String extensions' do

  it "camelcase() converts underscored string to captialized" do
    "abc_xyz".camelcase.should == "AbcXyz"
    "abc____xyz".camelcase.should == "AbcXyz"
    "a-bc_xyz".camelcase.should == "ABcXyz"
  end

  it "camelcase() converts whitespaced string to capitalized" do
    "abc xyz".camelcase.should == "AbcXyz"
    "abc  xyz".camelcase.should == "AbcXyz"
    "abc\txyz".camelcase.should == "AbcXyz"
    "abc\nxyz".camelcase.should == "AbcXyz"
  end

  it "camelcase(), when passed false, converts underscored string to capitalized w/ first char lowercase" do
    "abc_xyz".camelcase(false).should == "abcXyz"
    "abc____xyz".camelcase(false).should == "abcXyz"
  end

  it "camelcase(), when passed false, converts whitespaces string to capitalized w/ first char lowercase" do
    "abc xyz".camelcase(false).should == "abcXyz"
    "abc  xyz".camelcase(false).should == "abcXyz"
    "abc\txyz".camelcase(false).should == "abcXyz"
    "abc\nxyz".camelcase(false).should == "abcXyz"
  end

  it "camelcase(), deals with long, weird examples" do
    "the quick brown fox\nand three freeze fleas too".camelcase(false).should == "theQuickBrownFoxAndThreeFreezeFleasToo"
  end

  it "constantcase() will generate constants correctly" do
    "a/b".constantcase.should == "A::B"
    "a-b/c".constantcase.should == "AB::C"
  end

  it "snakecase() works" do
    "abcXyz".snakecase.should == "abc_xyz"
    "AbcXyz".snakecase.should == "abc_xyz"
    "theQuickBrownFoxAndThreeFreezeFleasToo".snakecase.should == "the_quick_brown_fox_and_three_freeze_fleas_too"
  end

end

class A
  class B
    class C
    end
  end
end

describe "Utils" do

  it "converts class names to the relevant constants" do
    Vertebra::Utils.constant(A::B::C.name).should == A::B::C
    Vertebra::Utils.constant("A::B::C").should == A::B::C

    # Return nil instead of blowing up if the constant can't be found.
    Vertebra::Utils.constant("Y::Z").should == nil
  end

  it "it should convert string keys to symbols" do
    hash = {'abc' => 123, :def => 456}
    newhash = Vertebra::Utils.keys_to_symbols(hash)
    newhash[:def].should == 456
    newhash['abc'].should == nil
    newhash[:abc].should == 123
  end

end
