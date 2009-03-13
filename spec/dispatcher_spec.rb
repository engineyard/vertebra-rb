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
require 'vertebra'
require 'vertebra/dispatcher'

include Vertebra

describe 'Vertebra Dispatcher' do

  include Vertebra::Utils

  before do
    $:.push File.join(File.dirname(__FILE__), 'mocks')
    @dispatcher = Dispatcher.new(nil, ['/cluster/rd00', '/node/0'])
    @dispatcher.register('mock_actor/actor')
  end

  it 'assign default resources' do
    @dispatcher.default_resources.should == [resource('/cluster/rd00'), resource('/node/0')]
  end

  it 'register an actor' do
    @dispatcher.actors.size.should == 1
  end

  it 'return proper candidate actors' do
    actor = @dispatcher.candidates('/', {:cluster => resource('/cluster/rd00'), :node => resource('/node/0'), :provides => resource('/mock')}).first
    actor.should be_a_kind_of(MockActor::Actor)
  end

  it 'should use the op in actor candidate selection' do
    @dispatcher.candidates('/list/numbers', ['/node/0']).map {|x| x.class}.should == [MockActor::Actor]
    @dispatcher.candidates('/list', ['/cluster/rd00']).map {|x| x.class}.should == [MockActor::Actor]
    @dispatcher.candidates('/there/is/nothing/here', ['/foo']).should == []
  end

  it 'handles missing actor libraries appropriately during registration' do
    registered = @dispatcher.register(['____xzpq____',nil])
    registered.should be_empty
  end

  it 'handles misnamed actor classes appropriately during registration' do
    registered = @dispatcher.register(['Parsedate',nil])
    registered.should be_empty
  end
end
