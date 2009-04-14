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

describe Vertebra::Conversion::Base64 do

  it 'should initialize with no errors when given correct parameters' do
    vb64 = Vertebra::Conversion::Base64.new("abc")
    vb64.should be_a_kind_of(Vertebra::Conversion::Base64)
    vb64 = Vertebra::Conversion::Base64.new("abc",:dec)
    vb64.should be_a_kind_of(Vertebra::Conversion::Base64)
    vb64 = Vertebra::Conversion::Base64.new(["abc"].pack("m"),:enc)
    vb64.should be_a_kind_of(Vertebra::Conversion::Base64)
  end

  it 'should raise an ArgumentError if the state is not :dec or :enc' do
    lambda { Vertebra::Conversion::Base64.new("abc",:foo) }.should raise_error(ArgumentError)
  end

  it 'should return properly decoded strings when #decoded is called' do
    vb64 = Vertebra::Conversion::Base64.new("abc")
    vb64.decoded.should == "abc"
    vb64 = Vertebra::Conversion::Base64.new(["abc"].pack("m"),:enc)
    vb64.decoded.should == "abc"
  end

  it 'should return properly encoded strings when #encoded is called' do
    enc = ["abc"].pack("m")
    vb64 = Vertebra::Conversion::Base64.new("abc")
    vb64.encoded.should == enc
    vb64 = Vertebra::Conversion::Base64.new(["abc"].pack("m"),:enc)
    vb64.encoded.should == enc
  end

  it 'should encode a plain string when the Base64::encode method is called' do
    Vertebra::Conversion::Base64.encode("abc").should == ["abc"].pack("m")
  end

  it 'should decode an encoded string when the Base64::decode method is called' do
    Vertebra::Conversion::Base64.decode(["abc"].pack("m")).should == "abc"
  end

  it 'should cope gracefully if it gets something other than a string' do
    vb64 = Vertebra::Conversion::Base64.new(123)
    vb64.decoded.should == "123"
    Vertebra::Conversion::Base64.decode(Vertebra::Conversion::Base64.encode(123)).should == "123"
  end
end


describe Vertebra::Conversion::DateTime do

  vertebra_datetime = nil
  time_now = Time.now.utc

  it 'should initialize with an array of year, month, day, hour, minute, second' do
    time_values = time_now.to_a[0..5].reverse
    vertebra_datetime = Vertebra::Conversion::DateTime.new(*time_values)
    vertebra_datetime.should be_a_kind_of(Vertebra::Conversion::DateTime)
    vertebra_datetime.year.should == time_values[0]
    vertebra_datetime.month.should == time_values[1]
    vertebra_datetime.day.should == time_values[2]
    vertebra_datetime.hour.should == time_values[3]
    vertebra_datetime.min.should == time_values[4]
    vertebra_datetime.sec.should == time_values[5]
  end

  it 'should correctly convert to a Time' do
    vertebra_datetime.to_time.should be_a_kind_of(Time)
    vertebra_datetime.to_time.to_s.should == time_now.to_s
  end

  it 'should correctly convert to a Date' do
    vertebra_datetime.to_date.should == Date.new(*time_now.to_a[0..5].reverse[0..2])
  end

  it 'should correctly convert to an array' do
    vertebra_datetime.to_a.should == time_now.to_a[0..5].reverse
  end

  it 'should correctly check equality to another Vertebra::Conversion::DateTime' do
    new_vertebra_datetime = Vertebra::Conversion::DateTime.new(*time_now.to_a[0..5].reverse)
    new_and_different_datetime = Vertebra::Conversion::DateTime.new(*Time.now.to_a[0..5].reverse)
    vertebra_datetime.should == new_vertebra_datetime
    vertebra_datetime.should_not == new_and_different_datetime
  end
end
