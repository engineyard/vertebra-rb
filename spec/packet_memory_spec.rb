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
require 'vertebra/packet_memory'

describe Vertebra::PacketMemory do

  before :each do
    @packet_memory = Vertebra::PacketMemory.new
    @packet_memory.set('a@b','aaa','111','pack1')
    @packet_memory.set('a@b','bbb','222','pack2')
    @packet_memory.set('b@c','aaa','333','pack3')
    @packet_memory.set('b@c','bbb','444','pack4')
    @packet_memory.set('b@c','ccc','555','pack5')
  end

  it 'queries items by jid and id' do
    @packet_memory.get_by_jid_and_id('a@b','111').should == 'pack1'
    @packet_memory.get_by_jid_and_id('a@b','222').should == 'pack2'
    @packet_memory.get_by_jid_and_id('b@c','333').should == 'pack3'
    @packet_memory.get_by_jid_and_id('b@c','444').should == 'pack4'
    @packet_memory.get_by_jid_and_id('b@c','555').should == 'pack5'
    @packet_memory.get_by_jid_and_id('z@z','555').should == nil
    @packet_memory.get_by_jid_and_id('b@c','666').should == nil
  end

  it 'queries items by token and id' do
    @packet_memory.get_by_token_and_id('aaa','111').should == 'pack1'
    @packet_memory.get_by_token_and_id('bbb','222').should == 'pack2'
    @packet_memory.get_by_token_and_id('aaa','333').should == 'pack3'
    @packet_memory.get_by_token_and_id('bbb','444').should == 'pack4'
    @packet_memory.get_by_token_and_id('ccc','555').should == 'pack5'
    @packet_memory.get_by_token_and_id('ddd','555').should == nil
    @packet_memory.get_by_token_and_id('ccc','666').should == nil
  end

  it 'deletes by token' do
    @packet_memory.delete_by_token('bbb')
    @packet_memory.get_by_token_and_id('aaa','111').should == 'pack1'
    @packet_memory.get_by_token_and_id('bbb','222').should == nil
    @packet_memory.get_by_token_and_id('aaa','333').should == 'pack3'
    @packet_memory.get_by_token_and_id('bbb','444').should == nil
    @packet_memory.get_by_token_and_id('ccc','555').should == 'pack5'
  end
end
