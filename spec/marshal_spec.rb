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
require 'conversion'

TYPES = ['string', 'nil', 'res', 'i4', 'boolean', 'base64', 'double', 'dateTime.iso8601', 'list', 'struct']

# MyStruct = Struct.new :foo, :bar
#
# s = MyStruct.new "hi", "there"
#
# args = {:foo => 42, :bar => "42", :baz => 42.0, :complex => s,
#         :yes => false, :qux => {:foo => 42, :baz => 'hi'},
#         :base => Vertebra::Base64.new("hi mom"),
#         :some_date => Time.now,
#         :some_array => [1, 'hi', :foo],
#         :cluster => res('/cluster/ey01'),
#         :hithere => nil}
#
# puts "hash args in:"
# puts
# p args
# puts
# puts "xml out:"
# puts
# xml = Vertebra::Marshal.encode(args)
# puts xml.to_s
# puts
# puts "args hash from xml:"
# puts
# p e = Vertebra::Marshal.decode( xml)
# p e.size

describe Vertebra::Marshal do
  it 'encodes a simple string' do
    r = Vertebra::Marshal.encode("abc")
    puts r
  end

  it 'return an empty hash when given a top-level element without a name attribute' do
    Vertebra::Marshal.decode(REXML::Document.new("<struct><i4>2</i4></struct>")).should == {}
  end

  it 'when given a struct element should return a valued hash nested in a hash' do
    Vertebra::Marshal.decode(REXML::Document.new("<struct name='result'><i4 name='value'>2</i4></struct>")).should == {'result' => {'value' => 2}}
  end

  it 'marshals and unmarshals an exception' do
    original_exception = RuntimeError.new('boom')
    encoded_exception = Vertebra::Marshal.encode({'exception' => original_exception})
    decoded_exception = Vertebra::Marshal.decode(encoded_exception)
    original_exception.class.should == decoded_exception['exception'].class
    original_exception.message.should == decoded_exception['exception'].message
  end

end
