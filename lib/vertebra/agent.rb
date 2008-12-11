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

require File.dirname(__FILE__) + '/base_agent'
require 'vertebra/dispatcher'
require 'vertebra/actor'
require 'vertebra/helpers/pubsub'

begin
require 'ruby-growl'
rescue LoadError
  logger.debug "Install the growl gem for growl support. Growl notifications disabled."
end

module Vertebra
  class Agent < BaseAgent

    attr_accessor :dispatcher, :herault_jid, :clients, :servers

    def initialize(jid, password, opts = {})

      super(jid, password, opts)

      @main_loop = GLib::MainLoop.new(nil,nil)
      @conn = LM::Connection.new

      set_callbacks

      @jid = Vertebra::JID.new(jid)
      @conn.jid = @jid.to_s
      @jid.resource ||= 'agent'
      @password = password

      @herault_jid = opts[:herault_jid] || 'herault@localhost/herault'
      @ttl = opts[:ttl] || 3600 # Default TTL for advertised resources is 3600 seconds.
      @dispatcher = ::Vertebra::Dispatcher.new(self, opts[:default_resources])

      @clients, @servers = {},{}

      # register actors specified in the config
      @dispatcher.register(opts[:actors]) if opts[:actors]

      # accept any incoming subscriptions automatically, and add herault to our roster

      if defined?(Growl)
        @growl = Growl.new "localhost", "vertebra", ["Vertebra Notification"]
      end

      self.accept_subscriptions = true
    end

    def set_callbacks
      @conn.set_disconnect_handler do |reason|
        logger.debug "Disconnected"
        @main_loop.quit
      end

      @conn.add_message_handler(LM::MessageType::MESSAGE) do |msg|
      logger.debug "GOT MSG #{msg.to_s}"
      handle_chat_message(msg)
      end

      @conn.add_message_handler(LM::MessageType::IQ) do |iq|
      logger.debug "GOT IQ #{iq.node.class}"
      handle_iq(iq)
      end    
    end

    def start
      super
      advertise_resources
      start_event_loop
    end

    def direct_op(op_type, to, *args)
      op = Vertebra::Op.new(op_type, *args)
      client = Vertebra::Protocol::Client.new(self, op, to)
      logger.debug("#direct_op #{op_type} #{to} #{args.inspect} for #{self}")
      client.make_request
      client
    end

    def op(op_type, to, *args)
      client = direct_op(op_type, to, *args)
      until client.done?
        sleep 0.005
      end
      client.results
    end

    # #discover takes as args a list of resources either in string form
    # (/foo/bar) or as instances of Vertebra::Resource.  It returns a list
    # of jids that will handle any of the resources.
    def discover(*resources)
      logger.debug "DISCOVERING: #{resources.inspect} on #{@herault_jid}"
      op('/security/discover', @herault_jid, *resources.collect {|r| Vertebra::Resource === r ? r.to_s : r})
    end


    def legacy_request(op_type, *args)
      params = args.pop if args.last.is_a? Hash
      jids = discover(*args)
      args.push params if params
      gather(scatter(jids['jids'], op_type, *args))
    end


    def request(op_type, *raw_args)
      # If the scope of the request is going to be specified, it should be
      # passed via a symbol as the first arg -- :single or :all.  That arg
      # will be removed from the list before issuing the request.  If a
      # scope is not given, :all is the assumed scope.
      
      case raw_args.first
      when :single
        scope = :single
        raw_args.shift
      when :all
        scope = :all
        raw_args.shift
      else
        scope = :all
      end
      
      resources = raw_args.select {|r| Vertebra::Resource === r}
      cooked_args = []
      specific_jids = []
      raw_args.each do |arg|
        next if Vertebra::Resource === arg
        
        if arg =~ /^jid:(.*)/
          specific_jids << $1
        else
          cooked_args << arg
        end
      end
      jids = discover(op_type,*resources)
      if Array === jids
        target_jids = jids.concat(specific_jids)
      else
        target_jids = jids['jids'].concat(specific_jids)
      end
      
      if scope == :all
        gather(scatter(target_jids, op_type, *cooked_args))
      else
        gather_first(scatter(target_jids, op_type, *cooked_args))
      end
    end


    def scatter(jids, op_type, *args)
      ops = {}
      jids.each do |jid|
        logger.debug "scatter# #{op_type}/#{jid}/#{args.inspect}"
        ops[jid] = direct_op(op_type, jid, *args)
      end
      ops
    end

    def single_scatter_and_gather(jids, op_type, *args)
      errors = [:error]
      result = nil
      jids.each do |jid|
        op = direct_op(op_type, jid, *args)
        until client.done?
          sleep(0.1)
        end
        if client.state == :commit # A completion
          result = client.results
          break
        elsif client.state == :error
          errors << client.results
        end
      end
      
      result ? result : errors
    end

    def gather(ops={})
      results = []
      while ops.size > 0 do
        ops.each do |jid, client|
          logger.debug "#{jid} -- #{client.state}"
          if client.done?
            results << client.results unless client.results.empty?
            ops.delete(jid)
          end
        end
        sleep(1)
      end
      results
    end

    def handle_iq(iq)
      logger.debug "handle_iq: #{iq.node}"

      # TODO: Would this chain of if statements be better written as a case
      # statement?
      
      if op = iq.node.get_child('op')
        if op['token'].size == 32
          logger.debug "instantiating new Server"
          server = Vertebra::Protocol::Server.new(self)
          Thread.new { server.receive_request(iq) }
        end
      end

      if ack = iq.node.get_child('ack')
        logger.debug "HANDLE ack"

        client = @clients[ack.get_attribute('token')]
        client.receive(iq) if client
      end

      if nack = iq.node.get_child('nack')
        logger.debug "HANDLE nack"
        client = @clients[nack.get_attribute('token')]
        client.receive(iq) if client
      end

      if result = iq.node.get_child('result')
        logger.debug "HANDLE result"
        client = @clients[result.get_attribute('token')]
        client.receive(iq) if client
      end

      if final = iq.node.get_child('final')
        logger.debug "HANDLE final"
        client = @clients[final.get_attribute('token')]
        client.receive(iq) if client
      end
    end

    def handle_chat_message(msg)
      # handle MUC invite
      logger.debug "GOT MSG #{msg.body}"
      if msg.first_element('x').is_a? Jabber::MUC::XMUCUser
        handle_invite(msg)
      else
        # handle 'cheap' operations
        if msg.body =~ /^\!(.*)/
          if out = handle_order($1)
            deliver(msg.from, out)
          end
        else
        # just notify the standard message
          notify(msg.body, msg.from.to_s)
        end
      end
    end

    def deliver(recipient, msg)
      m = LM::Message.new(recipient, LM::MessageType::MESSAGE)
      m.node.add_child('body', msg)
      @conn.send(m)
    end

    def handle_order(body)
      case body
      when 'resources'
        %Q{I am #{@jid}\nI provide these resources:\n#{@dispatcher.actors.join("\n") rescue nil}}
      when 'stats'
        Vertebra::Agent.default_status
      else
        # offer an api to authorized actor methods
      end
    end

    def handle_invite(msg)
      room_name = msg.from.to_s+"/#{self.jid.node}"
      muc = Jabber::MUC::SimpleMUCClient.new(@client)
      muc.join(Vertebra::JID.new(room_name))
      muc.say "Reporting for duty: #{self.class.default_status}"
      muc.on_message do |time, nick, text|
        if out = handle_order(text)
          muc.say(out)
        end
      end

      @rooms[room_name] = muc
    end

    def advertise_op(resources, ttl = @ttl)
      logger.debug "ADVERTISING: #{resources.inspect}"
      direct_op('/security/advertise', @herault_jid, :resources => resources, :ttl => ttl)
    end

    def unadvertise_op(resources)
      logger.debug "UNADVERTISING: #{resources.inspect}"
      direct_op('/security/advertise', @herault_jid, :resources => resources, :ttl => 0)
    end

    def advertise_resources
      resources = provided_resources
      advertise_op(resources)
      Thread.new {sleep(@ttl * 0.9); advertise_resources} # Readvertise before the resources expire
    end

    def provided_resources
      actors = @dispatcher.actors || []
      actors.collect {|actor| actor.provides }.flatten
    end

    def notify(title, msg)
      @growl.notify("Vertebra Notification", msg, title)
    end

    def self.default_status
      (File.exists?("/proc") ? File.read("/proc/loadavg") : `uptime`.split(":").last).gsub("\n", '')
    end
  end
end
