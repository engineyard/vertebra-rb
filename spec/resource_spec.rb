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
require 'vertebra/resource'

include Vertebra

describe 'Vertebra Resource' do

  it 'should be equal if input is equal' do
    Resource.new('/').should == Resource.new('/')
    Resource.new('/foo').should == Resource.new('/foo')
    Resource.new('/foo/bar').should == Resource.new('/foo/bar')
  end

  it '/ should be >= /foo' do
    (Resource.new('/') >= Resource.new('/foo')).should be_true
  end

  it '/foo/ should be <= /' do
    (Resource.new('/foo') <= Resource.new('/')).should be_true
  end

  it '/foo should be >= /foo/bar' do
    (Resource.new('/foo') >= Resource.new('/foo/bar')).should be_true
  end

  it '/foo/bar should be <= /foo' do
    (Resource.new('/foo/bar') <= Resource.new('/foo')).should be_true
  end

  it "should be uniq" do
    [Resource.new('/foo'),Resource.new('/foo')].uniq.size.should == 1
  end

  it "/foo should be > /foo/bar" do
    (Resource.new('/foo') > Resource.new('/foo/bar')).should be_true
  end

  it '/foo/bar should be < /foo' do
    (Resource.new('/foo/bar') < Resource.new('/foo')).should be_true
  end

  it 'it should compare' do
    (Resource.new('/foo/bar') <=> Resource.new('/foo')).should == -1
    (Resource.new('/foo') <=> Resource.new('/foo')).should == 0
    (Resource.new('/foo') <=> Resource.new('/foo/bar')).should == 1
  end
end
