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

class MockAgent
  attr_accessor :jid, :client, :clients, :herault_jid
  attr_accessor :op_client_backdoor

  def initialize
    @jid = 'test@localhost'
    @herault_jid = 'herault-test@localhost'
    @clients = Hash.new
  end

  def direct_op(op_type, to, *args)
    op = Vertebra::Op.new(op_type, *args)
    client = Vertebra::Protocol::Client.new(self, op, to)
    client.make_request
    client
  end

  def op(op_type, to, *args)
    @op_client_backdoor = client = direct_op(op_type, to, *args)
    until client.done?
      sleep 0.005
    end
    client.results
  end


end

class MockXMPPClient
  def configure_send(&block)
    @handle_send = block
  end

  def configure_send_with_id(&block)
    @handle_send_with_id = block
  end

  def send(xml)
    if @handle_send
      if block_given?
        yield(@handle_send.call(xml))
      else
        @handle_send.call(xml)
      end
    end
  end

  def send_with_id(xml)
    if @handle_send_with_id
      yield(@handle_send_with_id.call(xml))
    end
  end

  def send_with_reply(xml,&block)
    send_with_id(xml) {|x| block.call(x)}
  end
end


describe Vertebra::Protocol::Client do

  it 'sanity check the mocks' do
    #### Setup
    agent = MockAgent.new
    #    agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    #### End Setup

    agent.jid.should == 'test@localhost'
    agent.client.should be_an_instance_of(MockXMPPClient)
    agent.clients[:foo] = 123
    agent.clients[:foo].should == 123
    agent.clients.delete(:foo)
    agent.clients.size.should == 0

    agent.client.send_with_id(Vertebra::Authorization.new)
    agent.client.send(Vertebra::Authorization.new)
  end

  it 'should set instance variables on initialization, and #agent accessor should work' do
    #### Setup
    agent = MockAgent.new
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent,op,to)
    #### End Setup

    client.instance_variable_get('@agent').should == agent
    client.instance_variable_get('@state').should == :new
    client.instance_variable_get('@to').should == to
    client.instance_variable_get('@op').should == op
    client.agent.should == agent
  end

  it '#done? should return true if @state is one of :commit, :authfail, or :error' do
    #### Setup
    agent = MockAgent.new
    op = Vertebra::Op.new('/testop',"/test/test")
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent,op,to)
    #### End Setup

    client.instance_variable_set('@state',:commit)
    client.done?.should == true
    client.instance_variable_set('@state',:authfail)
    client.done?.should == true
    client.instance_variable_set('@state',:error)
    client.done?.should == true
  end

  it '#done? should return false if @state is anything else' do
    agent = MockAgent.new
    op = Vertebra::Op.new('/testop',"/test/test")
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    client.done?.should == false
  end

  it 'should return a token and advance state with a successful request' do
    #### Setup
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    agent = MockAgent.new
    #agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    xmppclient.configure_send_with_id do
      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
      r
    end
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    token = client.make_request
    #### End Setup

    token.should be_an_instance_of(String)
    token.should match(/\w{32}/)
    agent.clients[token].should be_an_instance_of(Vertebra::Protocol::Client)
    agent.clients[token].should == client
    client.state.should == :ready
  end

  it 'should set state to :error and set a @result with an unsuccessful request' do
    #### Setup
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    agent = MockAgent.new
    #agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    xmppclient.configure_send_with_id do
      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::ERROR)
      r
    end
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    token = client.make_request
    #### End Setup

    token.should == nil
    client.state.should == :error
    client.instance_variable_get('@result').should be_an_instance_of(String)
  end

  it 'should capture Jabber exceptions safely' do
    #### Setup
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    agent = MockAgent.new
    #agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    xmppclient.configure_send_with_id do
      raise Vertebra::JabberError
    end
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    token = client.make_request
    #### End Setup

    token.should == nil
    client.state.should == :error
    client.instance_variable_get('@result').should be_an_instance_of(String)
  end

  #  it 'process_ack_or_nack should process an ack' do
  #    #### Setup
  #    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
  #    agent = MockAgent.new
  #    #agent.clients = Hash.new
  #    xmppclient = MockXMPPClient.new
  #    xmppclient.configure_send_with_id do
  #      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
  #      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
  #      r
  #    end
  #    xmppclient.configure_send do |iq|
  #      iq
  #    end
  #    agent.client = xmppclient
  #    agent.jid = 'test@localhost'
  #    to = 'test@localhost'
  #    client = Vertebra::Protocol::Client.new(agent, op,to)
  #    iq = op.to_iq('/test/test','test@localhost')
  #    iq.node.add_child Vertebra::Ack.new(client.make_request)
  #    result_iq = client.process_ack_or_nack(iq)
  #    #### End Setup
  #
  #    client.state.should == :consume
  #    result_iq.should be_an_instance_of(LM::Message)
  #  end

  it 'process_ack_or_nack should process a nack' do
    #### Setup
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    agent = MockAgent.new
    #agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    xmppclient.configure_send_with_id do
      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
      r
    end
    xmppclient.configure_send do |iq|
      iq
    end
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    iq = op.to_iq('/test/test','test@localhost')
    iq.node.add_child Vertebra::Nack.new(client.make_request)
    result_iq = client.process_ack_or_nack(iq)
    #### End Setup

    client.state.should == :authfail
    client.instance_variable_get('@result').should match(/^Auth Failure/)
    result_iq.should be_an_instance_of(LM::Message)
  end

  #  it 'process_result_or_final should process a result' do
  #    #### Setup
  #    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
  #    agent = MockAgent.new
  #    #agent.clients = Hash.new
  #    xmppclient = MockXMPPClient.new
  #    xmppclient.configure_send_with_id do
  #      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
  #      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
  #      r
  #    end
  #    xmppclient.configure_send do |iq|
  #      iq
  #    end
  #    agent.client = xmppclient
  #    agent.jid = 'test@localhost'
  #    to = 'test@localhost'
  #    client = Vertebra::Protocol::Client.new(agent, op,to)
  #    iq = op.to_iq('/test/test','test@localhost')
  #    iq.node.add_child Vertebra::Result.new(client.make_request)
  #    result_iq = client.process_result_or_final(iq)
  #    #### End Setup
  #
  #    client.results.should be_an_instance_of(Hash)
  #    client.instance_variable_get('@results').size.should == 1
  #    result_iq.should be_an_instance_of(LM::Message)
  #  end

  it 'process_result_or_final should process a final' do
    #### Setup
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    agent = MockAgent.new
    #agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    xmppclient.configure_send_with_id do
      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
      r = op.to_iq('/test/test','test@localhost')
      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
      r
    end
    xmppclient.configure_send do |iq|
      iq
    end
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    iq = op.to_iq('/test/test','test@localhost')
    iq.node.add_child Vertebra::Final.new(client.make_request)
    result_iq = client.process_result_or_final(iq)
    #### End Setup

    client.state.should == :commit
    agent.clients.size.should == 0
  end

  it 'should receive when state is :ready or :consume' do
    #### Setup
    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
    agent = MockAgent.new
    #agent.clients = Hash.new
    xmppclient = MockXMPPClient.new
    xmppclient.configure_send_with_id do
      op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
      r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
      r
    end
    xmppclient.configure_send do |iq|
      iq
    end
    agent.client = xmppclient
    agent.jid = 'test@localhost'
    to = 'test@localhost'
    client = Vertebra::Protocol::Client.new(agent, op,to)
    stub(client).process_ack_or_nack {:ack_or_nack}
    stub(client).process_result_or_final {:result_or_final}
    #### End Setup

    iq = op.to_iq('/test/test','test@localhost')
    iq.node.add_child Vertebra::Nack.new(client.make_request)
    client.instance_variable_set('@state', :ready)
    client.receive(iq).should == :ack_or_nack

    iq = op.to_iq('/test/test','test@localhost')
    iq.node.add_child Vertebra::Result.new(client.make_request)
    client.instance_variable_set('@state', :consume)
    client.receive(iq)
    client.receive(iq).should == :result_or_final
  end

end

describe Vertebra::Protocol::Server do

  it 'should set instance variables on initialization' do
    #### Setup
    agent = MockAgent.new
    server = Vertebra::Protocol::Server.new(agent)
    #### End Setup

    server.agent.should == agent
    server.state.should == :new
  end

  #it 'receive_request' do
  #  #### Setup
  #  xmppclient = MockXMPPClient.new
  #  xmppclient.configure_send_with_id do
  #    op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
  #    r = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
  #    r
  #  end
  #  xmppclient.configure_send do |iq|
  #    iq
  #  end
  #  agent = MockAgent.new
  #  agent.client = xmppclient
  #  server = Vertebra::Protocol::Server.new(agent)
  #  op = Vertebra::Op.new('/testop',"/test/test",{'from' => '/george', 'to' => '/man/in/yellow/hat'})
  #  server_iq = op.to_iq('/test/test','test@localhost')
  #
  #    receive_client = Vertebra::Protocol::Client.new(agent,op,'test@localhost')
  #    receive_iq = op.to_iq('/test/test','test@localhost',LM::MessageSubType::RESULT)
  #
  #    vrn = Vertebra::Result.new(receive_client.make_request)
  #
  #    receive_iq.node.add_child vrn
  #
  #    #### End Setup
  #
  #    Thread.new do
  #      # Fake the essential parts of the protocol exchange that the server is expecting.
  #      sleep 0.5
  #      agent.op_client_backdoor.instance_variable_set('@state',:consume)
  #      agent.op_client_backdoor.receive(receive_iq)
  #      sleep 0.5
  #      agent.op_client_backdoor.instance_variable_set('@state',:commit)
  #    end
  #
  #    # Without proper authentcaton, will terminate.
  #    server.receive_request(server_iq).should == :terminated
  #  end
end
