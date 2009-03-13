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
require 'vertebra/actor'

class DummyActor < Vertebra::Actor
  provides '/mock'

  def array_of_numbers(options = {})
    options['alternate'] ? [2,3,4] : [1,2,3]
  end
end

class AutoDummyActor < Vertebra::Actor
  bind_op '/mock/num', :num
  bind_op '/mockery/taunt', :taunt
end

describe Vertebra::Actor do
  include Vertebra::Utils

  before(:all) do
    @dummy = DummyActor.new
    @dummy.default_resources = [resource('/cluster/rd00'), resource('/node/1')]
  end

  it 'should return correct shell command output' do
    output = `hostname`
    result = @dummy.spawn("hostname")
    puts result.inspect
    result[:stderr].should == ''
    result[:result].should == output
    result[:status].should be_a_kind_of(Process::Status)
  end

  it 'should raise an error when running a shell command with a non-zero exit status' do
    lambda { @dummy.spawn("ls -non-existent-option") }.should raise_error(Vertebra::ActorInternalError)
  end

  it 'should add accessors to the class which includes it' do
    @dummy.respond_to?(:default_resources).should == true
    @dummy.respond_to?(:agent).should == true
  end

  it 'should provide resources based on the contents of the RESOURCES constant, plus default resources' do
    @dummy.provides.should == ['/cluster/rd00', '/node/1', '/mock'].collect { |r| resource(r) }
  end

  it 'should permit multiple "provides" calls to be additive' do
    dummy_too = DummyActor.dup
    dummy_too.class_eval <<EOC
provides '/mock2'
EOC
    d2 = dummy_too.new
    d2.provides.should == ['/mock','/mock2'].collect {|r| resource(r)}
  end

  it 'should populate the provided resources from bound ops, automatically' do
    auto_dummy = AutoDummyActor.new
    auto_dummy.provides.should == ['/mock','/mockery'].collect {|r| resource(r)}
  end

  it 'should properly match top-level required resources with lower-level provided resources' do
    auto_dummy = AutoDummyActor.new
    auto_dummy.can_provide?([resource('/mock')]).should
    auto_dummy.can_provide?([resource('/mockery')]).should
  end

  it 'should not match a top-level required resource with a lower-level one that is not the root of a provided resource' do
    auto_dummy = AutoDummyActor.new
    auto_dummy.can_provide?([resource('/missing')]).should_not
    auto_dummy.can_provide?([resource('/mock/test')]).should_not
  end

  it 'should handle both automagic resource identification with explicit resource identification' do
    dummy_too = DummyActor.dup
    dummy_too.class_eval <<EOC
bind_op '/mockery/taunt', :taunt
EOC
    d2 = dummy_too.new
    d2.provides.should == ['/mock','/mock2','/mockery'].collect {|r| resource(r)}
  end

  it 'should generate correct output from the open4 spawn wrapper' do
    output = @dummy.spawn "gem", "list", "sources"
    output[:status].should_not be(nil)
    output[:result].should_not be(nil)
    output[:stderr].should == ""
  end

  it 'should generate correct output from the open4 spawn wrapper with formatting block' do
    output = @dummy.spawn "gem", "list", "sources" do |out|
      @old_out = out
      out.reverse
    end
    output[:status].should_not be(nil)
    output[:result].should == @old_out.reverse
    output[:stderr].should == ""
  end

  it 'should return array of numbers' do
    @dummy.array_of_numbers({'something' => 'foo'}).should == [1,2,3]
  end

  it 'should return different array of numbers' do
    @dummy.array_of_numbers({'alternate' => true}).should == [2,3,4]
  end

end
