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
require 'vertebra/deferrable'
require 'vertebra/synapse'
require 'glib2'

describe Vertebra::Deferrable do

  # callback
  it 'test callback()/callbacks()' do
    df = Vertebra::Deferrable::Klass.new
    df.callbacks.length.should == 0
    df.callback {7}
    df.callbacks.length.should == 1
    df.callback {:seven}
    df.callbacks.length.should == 2
  end
  
  it 'test callback() with preset status == :succeeded' do
    df = Vertebra::Deferrable::Klass.new
    df.instance_variable_set('@deferred_status',:succeeded)
    df.callback {7}.should == 7
  end
  
  it 'test callback() wih preset status == :failed' do
    df = Vertebra::Deferrable::Klass.new
    df.instance_variable_set('@deferred_status',:failed)
    df.callback {7}.class.should == Vertebra::Deferrable::SetCallbackFailed
  end
  
  # errback
  it 'test errback()/errbacks()' do
    df = Vertebra::Deferrable::Klass.new
    df.errbacks.length.should == 0
    df.errback {9}
    df.errbacks.length.should == 1
    df.errback {:nine}
    df.errbacks.length.should == 2
  end
  
  it 'test errback() with preset status == :failed' do
    df = Vertebra::Deferrable::Klass.new
    df.instance_variable_set('@deferred_status',:failed)
    df.errback {9}.should == 9
  end
  
  it 'test errback() with preset status == :succeeded' do
    df = Vertebra::Deferrable::Klass.new
    df.instance_variable_set('@deferred_status',:succeeded)
    df.errback {9}.class.should == Vertebra::Deferrable::SetCallbackFailed
  end

  # set_deferred_status
  it 'test set_deferred_status() after callback()' do
    df = Vertebra::Deferrable::Klass.new
    df.callback {7}
    df.set_deferred_status(:succeeded).should == 7
  end
  
  it 'test set_deferred_status() before callback()' do
    df = Vertebra::Deferrable::Klass.new
    df.set_deferred_status(:succeeded)
    df.callback {7}.should == 7
  end
  
  it 'test set_deferred_status() after multiple callback()s' do
    df = Vertebra::Deferrable::Klass.new
    @cb_results = []
    df.callback {@cb_results << 7}
    df.callback {@cb_results << :seven}
    df.set_deferred_status(:succeeded)
    @cb_results.should == [7, :seven]
  end
  
  it 'test set_deferred_status() with args after callback()' do
    df = Vertebra::Deferrable::Klass.new
    @cb_results = []
    df.callback {|x,y| @cb_results << x}
    df.callback {|x,y| @cb_results << y}
    df.set_deferred_status(:succeeded, 7 ,:seven)
    @cb_results.should == [7, :seven]
  end

  it 'test set_deferred_status() after callback()/errback(), status == :succeeded' do
    df = Vertebra::Deferrable::Klass.new
    df.callback {7}
    df.errback {9}
    df.set_deferred_status(:succeeded).should == 7
  end

  it 'test set_deferred_status() after callback()/errback(), status == :failed' do
    df = Vertebra::Deferrable::Klass.new
    df.callback {7}
    df.errback {9}
    df.set_deferred_status(:failed).should == 9
  end  

  # timeout
  it 'test timeout()' do
    df = Vertebra::Deferrable::Klass.new
    @cb_results = []
    @main_loop = GLib::MainLoop.new(nil,nil)
    df.errback {@cb_results << 9; @main_loop.quit}
    GLib::Timeout.add(1) {df.timeout = 1;false}
    GLib::Timeout.add(4000) {@cb_results << :timeout_failed; @main_loop.quit}
    
    @main_loop.run
    @cb_results.first.should == 9
  end
  
  # cancel_timeout
  it 'test cancel_timeout()' do
    df = Vertebra::Deferrable::Klass.new
    @cb_results = []
    @main_loop = GLib::MainLoop.new(nil,nil)
    df.errback {@cb_results << 9; @main_loop.quit}
    GLib::Timeout.add(1) {df.timeout = 2; false}
    GLib::Timeout.add(900) {df.cancel_timeout; false}
    GLib::Timeout.add(4000) {@cb_results << :timeout_failed; @main_loop.quit}
    
    @main_loop.run
    @cb_results.first.should == :timeout_failed
  end
  
  # set_deferred_success
  it 'test set_deferred_success()' do
    df = Vertebra::Deferrable::Klass.new
    df.callback {7}
    df.set_deferred_success.should == 7
  end
  
  # set_deferred_failure
  it 'test set_deferred_failure()' do
    df = Vertebra::Deferrable::Klass.new
    df.errback {9}
    df.set_deferred_failure.should == 9
  end
  
  # succede
  it 'test succeed()' do
    df = Vertebra::Deferrable::Klass.new
    df.callback {7}
    df.succeed.should == 7
  end
  
  # fail
  it 'test fail()' do
    df = Vertebra::Deferrable::Klass.new
    df.errback {9}
    df.fail.should == 9
  end
  
end

describe Vertebra::Synapse do
  it 'test conditional()/conditions()' do
    df = Vertebra::Synapse.new
    df.conditions.length.should == 0
    df.condition {7}
    df.conditions.length.should == 1
    df.condition {:seven}
    df.conditions.length.should == 2    
  end
  
  it 'test deferred_status?() on :succeded' do
    df = Vertebra::Synapse.new
    df.condition {:succeded}
    df.deferred_status?.should == :succeded
  end
  
  it 'test deferred_status?() on layered :succeded' do
    df = Vertebra::Synapse.new
    df.condition {:succeded}
    df.condition {:succeded}
    df.deferred_status?.should == :succeded
  end
  
  it 'test deferred_status?() on :deferred' do
    df = Vertebra::Synapse.new
    df.condition {:deferred}
    df.deferred_status?.should == :deferred
  end
  
  it 'test deferred_status() on :succeded/deferred' do
    df = Vertebra::Synapse.new
    df.condition {:succeded}
    df.condition {:deferred}
    df.deferred_status?.should == :deferred
    
    df = Vertebra::Synapse.new
    df.condition {:succeded}
    df.condition {:deferred}
    df.condition {:succeded}
    df.deferred_status?.should == :deferred
  end
  
  it 'test deferred_status?() on :deferred/failed' do
    df = Vertebra::Synapse.new
    df.condition {:deferred}
    df.condition {:failed}
    df.deferred_status?.should == :deferred
  end
  
  it 'test deferred_status?() on :failed' do
    df = Vertebra::Synapse.new
    df.condition {:failed}
    df.deferred_status?.should == :failed
  end
  
  it 'test deferred_status?() on :succeded/failed' do
    df = Vertebra::Synapse.new
    df.condition {:succeded}
    df.condition {:failed}
    df.deferred_status?.should == :failed
    
    df = Vertebra::Synapse.new
    df.condition {:succeded}
    df.condition {:failed}
    df.condition {:succeded}
    df.deferred_status?.should == :failed
  end
  
  it 'test deferred_status?() on :failed/deferred' do
    df = Vertebra::Synapse.new
    df.condition {:failed}
    df.condition {:deferred}
    df.deferred_status?.should == :failed
  end
  
  it 'test deferred_status?() with implicit success' do
    df = Vertebra::Synapse.new
    df.condition {true}
    df.deferred_status?.should == :succeeded
  end
  
  it 'test deferred_status?() with implicit failure' do
    df = Vertebra::Synapse.new
    df.condition {false}
    df.deferred_status?.should == :failed
  end
  
  it 'test synapse data storage' do
    df = Vertebra::Synapse.new
    df[:abc] = 123
    df['seven'] = 7
    df[:abc].should == 123
    df['seven'].should == 7
  end
end
