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
require 'vertebra/agent'

# Specs to test the protocol portion of Vertebra.

describe Vertebra::Op do

  it 'should allow initialization with an array' do
    op = Vertebra::Op.new('/testop',"/test/test")
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['/test/test'].should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@args')['/test/test'].to_s.should == '/test/test'
  end

  it 'should allow initialization with a hash' do
    op = Vertebra::Op.new('/testop',{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['from'].should == '/george'
    op.instance_variable_get('@args')['to'].should == '/man/in/yellow/hat'
  end

  it 'should allow initialization with an array and a hash' do
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    op.should be_kind_of(Vertebra::Op)
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['/test/test'].should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@args')['/test/test'].to_s.should == '/test/test'
    op.instance_variable_get('@op_type').should be_kind_of(Vertebra::Resource)
    op.instance_variable_get('@op_type').to_s.should == '/testop'
    op.instance_variable_get('@args')['from'].should == '/george'
    op.instance_variable_get('@args')['to'].should == '/man/in/yellow/hat'
  end

  # todo: write a decent test of #to_iq

end

describe Vertebra::Protocol::Client do

end

describe Vertebra::Protocol::Server do

end
