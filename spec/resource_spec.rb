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

describe 'Vertebra Resource' do
  include Vertebra::Utils

  it 'should be equal if input is equal' do
    resource('/').should == resource('/')
    resource('/foo').should == resource('/foo')
    resource('/foo/bar').should == resource('/foo/bar')
  end

  it '/ should be >= /foo' do
    resource('/').should >= resource('/foo')
    resource('/bar').should_not >= resource('/foo')
  end

  it '/foo/ should be <= /' do
    resource('/foo').should <= resource('/')
    resource('/foo').should <= resource('/foo')
    resource('/foo').should_not <= resource('/bar')
  end

  it '/foo should be >= /foo/bar' do
    resource('/foo').should >= resource('/foo/bar')
    resource('/foo/bar').should >= resource('/foo/bar')
    resource('/bar/foo').should_not >= resource('/foo/bar')
  end

  it '/foo/bar should be <= /foo' do
    resource('/foo/bar').should <= resource('/foo')
    resource('/foo/bar').should <= resource('/foo/bar')
    resource('/foo/bar').should_not <= resource('/bar/foo')
  end

  it "should be uniq" do
    [resource('/foo'),resource('/foo')].uniq.should have(1).entries
  end

  it "supports > comparisons" do
    resource('/foo').should > resource('/foo/bar')
    resource('/foo/bar').should_not > resource('/foo/bar')
    resource('/foo').should_not > resource('/bar')
  end

  it 'supports < comparisons' do
    resource('/foo/bar').should < resource('/foo')
    resource('/foo/bar/baz').should < resource('/foo')
    resource('/foo/bar/baz').should < resource('/')
    resource('/foo/bar').should_not < resource('/foo/bar')
  end

  it 'it should compare' do
    (resource('/foo/bar') <=> resource('/foo')).should == -1
    (resource('/foo') <=> resource('/foo')).should == 0
    (resource('/foo') <=> resource('/foo/bar')).should == 1
  end

  it 'has a first part' do
    resource('/foo/bar').first.should == "foo"
  end

  it 'has a last part' do
    resource('/foo/bar/baz').last.should == "baz"
  end
end
