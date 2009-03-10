# Copyright 2009, Engine Yard, Inc.
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
require 'vertebra/sous_chef.rb'

describe Vertebra::SousChef do
  def prepare(*args)
    Vertebra::SousChef.prepare(*args)
  end

  def expect_error(*args, &block)
    block.should raise_error(*args)
  end

  it 'should set some defaults' do
    entree = prepare
    entree.args.should == {}
    entree.jids.should == []
    entree.resources.should == []
    entree.scope.should == :all
  end

  it 'should set scope to the first argument, if it is a symbol' do
    prepare(:all).scope.should == :all
    prepare(:single).scope.should == :single
    prepare(:foo).scope.should == :foo
    prepare(:arg1 => 42).scope.should == :all
  end

  it 'should set cooked to the remaining argument' do
    prepare(:arg1 => 42).args.should == {:arg1 => 42}
    prepare(:single, :foo => :bar).args.should == {:foo => :bar}
  end

  it 'should extract resources' do
    resources = (0..1).collect {|i| res("/#{i}")}
    prepare(:foo => resources[0]).resources.should == [resources[0]]
    prepare(:foo => {:bar => resources[1]}).resources.should == [resources[1]]
    prepare(:foo => resources).resources.should == resources
  end

  it 'should convert resource strings to resources' do
    prepare("/foo").args.should == {"/foo" => res("/foo")}
  end

  it 'should convert "a=b" into {a => b}' do
    prepare("a=b").args.should == {"a" => "b"}
  end

  it 'should merge multiple arguments' do
    prepare({:foo => 1}, {:bar => 2}).args.should == {:foo => 1, :bar => 2}
    cooked = prepare("a=b", {:foo => 1}, "/res").args
    cooked.should == {"a" => "b", :foo => 1, "/res" => res("/res")}
  end

  it 'should extract jids' do
    chef = prepare("jid:foo@bar/baz")
    chef.args.should == {}
    chef.jids.should == ["foo@bar/baz"]
  end
end
