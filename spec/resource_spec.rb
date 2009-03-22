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
    (Resource.new('/bar') >= Resource.new('/foo')).should be_false
  end

  it '/foo/ should be <= /' do
    (Resource.new('/foo') <= Resource.new('/')).should be_true
    (Resource.new('/foo') <= Resource.new('/foo')).should be_true
    (Resource.new('/foo') <= Resource.new('/bar')).should be_false
  end

  it '/foo should be >= /foo/bar' do
    (Resource.new('/foo') >= Resource.new('/foo/bar')).should be_true
    (Resource.new('/foo/bar') >= Resource.new('/foo/bar')).should be_true
    (Resource.new('/bar/foo') >= Resource.new('/foo/bar')).should be_false
  end

  it '/foo/bar should be <= /foo' do
    (Resource.new('/foo/bar') <= Resource.new('/foo')).should be_true
    (Resource.new('/foo/bar') <= Resource.new('/foo/bar')).should be_true
    (Resource.new('/foo/bar') <= Resource.new('/bar/foo')).should be_false
  end

  it "should be uniq" do
    [Resource.new('/foo'),Resource.new('/foo')].uniq.size.should == 1
  end

  it "/foo should be > /foo/bar" do
    (Resource.new('/foo') > Resource.new('/foo/bar')).should be_true
    (Resource.new('/foo/bar') > Resource.new('/foo/bar')).should be_false
  end

  it '/foo/bar should be < /foo' do
    (Resource.new('/foo/bar') < Resource.new('/foo')).should be_true
    (Resource.new('/foo/bar') < Resource.new('/foo/bar')).should be_false
  end

  it 'it should compare' do
    (Resource.new('/foo/bar') <=> Resource.new('/foo')).should == -1
    (Resource.new('/foo') <=> Resource.new('/foo')).should == 0
    (Resource.new('/foo') <=> Resource.new('/foo/bar')).should == 1
  end

  it 'has a first part' do
    Resource.new('/foo/bar').first.should == "foo"
  end

  it 'has a last part' do
    Resource.new('/foo/bar/baz').last.should == "baz"
  end
end
