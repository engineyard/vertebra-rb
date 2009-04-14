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
$: << "#{File.dirname(__FILE__)}/mocks"
puts $:.inspect
require 'vertebra'
require 'vertebra/agent'
require 'vertebra/packet_memory'
require 'vertebra/synapse_queue'

# Specs to test the protocol portion of Vertebra.

class Mock
  attr_accessor :packet_memory, :servers, :dispatcher

  def initialize
    @packet_memory = Vertebra::PacketMemory.new
    @servers = {}
    @dispatcher = Vertebra::Dispatcher.new(self, Vertebra::KeyedResources.new)
    @dispatcher.register ["mock_actor/actor"]
    yield(self) if block_given?
  end

  def def(symbol, &block)
    self.class.class_eval do
      define_method symbol, &block
    end
  end

end

describe Vertebra::Protocol::Client do
  AGENT_JID = "agent@example.com"
  REMOTE_JID = "test@example.com"
  DEFAULT_ID = "42"

  before :each do
    @synapses = synapses = Vertebra::SynapseQueue.new
    $jid = $id = $children = nil

    @agent = Mock.new do |mock|
      mock.def(:connection_is_open_and_authenticated?) {true}
      mock.def(:jid) {AGENT_JID}
      mock.def(:remove_client) {|token| }
      mock.def(:send_iq) {|iq| }
      mock.def(:send_result) {|*args| $jid, $id, $children, indirect_block, direct_block = args}
      mock.def(:send_iq_with_synapse) {|iq, protocol| }
      mock.def(:add_client) {|token, client| }
      mock.def(:enqueue_synapse) {|synapse| synapses << synapse}
      mock.def(:do_or_enqueue_synapse) {|synapse| synapses << synapse}
      mock.def(:parse_token) {|node| }
    end

    @to = "to@localhost"
    @token = Vertebra.gen_token
    @client = Vertebra::Protocol::Client.start(@agent, Vertebra::Utils.resource("/foo"), @token, @to, :all, {})
  end

  it 'Should enqueue a synapse during initialization' do
    @client.state.should == :new
    @synapses.size.should == 1
  end

  it 'Should defer if connection is not open and authenticated' do
    synapse = @synapses.first

    @agent.def(:connection_is_open_and_authenticated?) {:deferred}
    @synapses.fire
    @synapses.size.should == 1
    @synapses.first.should == synapse
  end

  it 'Should send an IQ' do
    synapse = @synapses.first

    actual_iq = nil
    @agent.def(:send_iq) {|iq| actual_iq = iq}

    2.times { @synapses.fire }

    actual_iq.node.child.get_attribute('token').should == @token
  end

  def create_iq
    iq = LM::Message.new(REMOTE_JID, LM::MessageType::IQ)
    iq.node.set_attribute('id', DEFAULT_ID)
    iq.node.set_attribute('xml:lang','en')
    iq.node.set_attribute('type', 'set')
    iq
  end

  def create_incoming_iq
    iq = create_iq
    iq.node.set_attribute('to', AGENT_JID)
    iq.node.set_attribute('from', REMOTE_JID)
    iq
  end

  def create_response_iq
    iq = create_iq
    iq.node.set_attribute("to", REMOTE_JID)
    iq.node.set_attribute('type', 'result')
    iq
  end

  def do_stanza(method, type)
    iq = create_incoming_iq
    stanza = iq.node.add_child(type.to_s)
    yield(stanza) if block_given?

    @client.send(method, iq, type, stanza)
    @synapses.fire

    expected_iq = create_response_iq
    $jid.should == REMOTE_JID
    $id.should == DEFAULT_ID
  end

  it 'Should respond to a nack when in the ready state' do
    @synapses.clear
    @client.instance_eval { @state = :ready }
    do_stanza(:process_ack_or_nack, :nack)
    @client.state.should == :authfail
  end

  it 'Should respond to an ack when in the ready state' do
    @synapses.clear
    @client.instance_eval { @state = :ready }
    do_stanza(:process_ack_or_nack, :ack)
    @client.state.should == :consume
  end

  it 'Should respond to a result when in the consume state' do
    @synapses.clear
    @client.instance_eval { @state = :consume}
    do_stanza(:process_data_or_final, :result)
    @client.state.should == :consume
  end

  it 'Should respond to an error when in the consume state' do
    @synapses.clear
    @client.instance_eval { @state = :consume }
    do_stanza(:process_data_or_final, :error)
    @client.state.should == :error
  end

  it 'Should respond to a final when in the consume state' do
    @synapses.clear
    @client.instance_eval { @state = :consume }
    do_stanza(:process_data_or_final, :final)
    @client.state.should == :commit
  end
end

describe Vertebra::Protocol::Server do
  AGENT_JID = "agent@example.com"
  REMOTE_JID = "test@example.com"
  DEFAULT_ID = "42"

  before :each do
    @synapses = synapses = Vertebra::SynapseQueue.new
    $jid = $id = $children = nil

    @agent = Mock.new do |mock|
      mock.def(:connection_is_open_and_authenticated?) {true}
      mock.def(:jid) {AGENT_JID}
      mock.def(:remove_client) {|token| }
      mock.def(:send_iq) {|iq| }
      mock.def(:send_result) {|*args| $jid, $id, $children, indirect_block, direct_block = args}
      mock.def(:send_iq_with_synapse) {|iq, protocol| }
      mock.def(:add_client) {|token, client| }
      mock.def(:enqueue_synapse) {|synapse| synapses << synapse}
      mock.def(:do_or_enqueue_synapse) {|synapse| synapses << synapse}
      mock.def(:parse_token) {|node| }
    end
  end

  # All actors should return their results in a Hash.
  it 'Should execute an actor method that returns a Hash, and return a response' do
    iq = LM::Message.new(REMOTE_JID,LM::MessageType::IQ,LM::MessageSubType::SET)
    iq.node.add_child('op')
    iq.node.child['scope'] = 'all'
    iq.node.child['token'] = 'd6ebe3c400caed1419df2698f0adbb2a'
    iq.node.child['type'] = '/list/cipher'
    iq.node.child['xmlns'] = 'http://xmlschema.engineyard.com/agent/api'

    actual_iq = nil
    @agent.def(:send_iq) {|iq| actual_iq = iq}
    server = Vertebra::Stanza.handle(@agent, iq)
    dispatcher = server.process_operation
    4.times { @synapses.fire }
    response = Vertebra::Marshal.decode(actual_iq.node.child)
    response.keys.sort.should == %w{ a b c d e f g h i j k l m n o p q r s t u v w x y z }
  end

  # Actors which do not return hashes should be avoided.
  it "Should execute an actor method that doesn't return a Hash, and return a response" do
    iq = LM::Message.new(REMOTE_JID,LM::MessageType::IQ,LM::MessageSubType::SET)
    iq.node.add_child('op')
    iq.node.child['scope'] = 'all'
    iq.node.child['token'] = 'd6ebe3c400caed1419df2698f0adbb2b'
    iq.node.child['type'] = '/list/numbers'
    iq.node.child['xmlns'] = 'http://xmlschema.engineyard.com/agent/api'

    actual_iq = nil
    @agent.def(:send_iq) {|iq| actual_iq = iq}
    server = Vertebra::Stanza.handle(@agent, iq)
    dispatcher = server.process_operation
    4.times { @synapses.fire }
    response = Vertebra::Marshal.decode(actual_iq.node.child)['response']
    response.should == [1,2,3]
  end

  it 'Should handle an actor method that throws an exception, and return an exception' do
    iq = LM::Message.new(REMOTE_JID,LM::MessageType::IQ,LM::MessageSubType::SET)
    iq.node.add_child('op')
    iq.node.child['scope'] = 'all'
    iq.node.child['token'] = 'd6ebe3c400caed1419df2698f0adbb2c'
    iq.node.child['type'] = '/list/kaboom'
    iq.node.child['xmlns'] = 'http://xmlschema.engineyard.com/agent/api'

    actual_iq = nil
    @agent.def(:send_iq) {|iq| actual_iq = iq}
    server = Vertebra::Stanza.handle(@agent, iq)
    dispatcher = server.process_operation
    4.times { @synapses.fire }
    decoded_response = Vertebra::Marshal.decode(actual_iq.node.child)
    decoded_response.keys.should == ['error']
    error = decoded_response['error']
    error.class.should == RuntimeError
    error.message.should == 'Kaboom!'
  end

end
