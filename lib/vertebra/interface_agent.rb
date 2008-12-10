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

require File.dirname(__FILE__) + '/agent'

begin
require 'ruby-growl'
rescue LoadError
  logger.error "Install the growl gem for growl support. Growl notifications disabled."
end

module Vertebra
  class InterfaceAgent < Agent

    attr_accessor :followed_nodes

    include DRb::DRbUndumped if defined?(DRb::DRbUndumped)

    def initialize(jid, password, opts={})
      opts[:default_resources] ||= "/#{`hostname`}"
      super(jid, password, opts)

      if defined?(Growl)
        @growl = Growl.new "localhost", "vertebra", ["Vertebra Notification"]
      end

    end

    # this is only called from DRb connected as a way to get a shell into
    # the agents world. This call returns an id token you can use to get the result.

    def get_op(jid, op_type, args = {})
      iq = Jabber::Iq.new(:get)
      operation(iq, jid, op_type, args)
    end

    def set_op(jid, op_type, args = {})
      iq = Jabber::Iq.new(:set)
      operation(iq, jid, op_type, args)
    end

    def operation(iq, jid, op_type, args = {})
      jid = Vertebra::JID.new(jid)
      iq.to = jid
      iq.from = @jid
      token = "#{Vertebra.gen_token}:#{Vertebra.gen_token}"
      op = Vertebra::Operation.new(op_type, token)

      Vertebra::Marshal.encode(args).children.each do |el|
        op.add_element(el)
      end

      iq.add(op)

      logger.debug "OPERATION SEND: #{op.token} #{op.inspect}"
      send_operation(iq)
      token.split(':').last
    end

    # @agent.discover '/cluster/ey01', '/slice', '/gem'
    # # => [array, of, jids, that, can, handle, this, request]
    def discover(*resources)
      logger.debug "DISCOVERING: #{resources.inspect}"
      token = Vertebra.gen_token
      op = Vertebra::Operation.new('/security/discover', token)
      iq = Jabber::Iq.new(:get, Vertebra::JID.new(@herault_jid))
      iq.from = @jid
      resources.each{|r| op.add(Vertebra::Res.new(r)) }
      iq.add(op)

      begin
        res = nil
        @client.send_with_id(iq) do |answer|
          logger.debug "Heralt Discovered: #{answer}"
          if answer.type == :result
            res = Vertebra::Marshal.decode(answer.first_element('result'))
          end
        end
      rescue Vertebra::JabberError => e
        res = e.message
      end
      res
    end

    # >> @agent.broadcast('list', '/cluster/ey04', '/node/5', '/xen')
    # => {"ey04-n05"=>[{"ey04-s00042"=>{"memory"=>640, "vcpus"=>1, "id"=>"9", "times"=>90.9, "state"=>"-b----"},
    # "ey04-s00010"=>{"memory"=>4096, "vcpus"=>2, "id"=>"6", "times"=>13406.3, "state"=>"-b----"}}]}
    def broadcast(op, *args)
      params = args.pop if args.last.is_a? Hash
      jids = discover(*args)
      hsh = {}
      args.each do |arg|
        hsh[arg] = res(arg)
      end

      # if the last resource is a hash, it's assumed that it's an argument hash
      hsh.merge!(params) if params

      # send an operation to every  jid in the list,
      # wait for and gather up the results from all ops
      gather(scatter(jids['jids'], op, hsh))
    end

    # takes a hash of token/jid pairs and attempts to retrieve their results
    def gather(token_hash)
      results_hash = {}
      while token_hash.size > 0 do
        sleep 0.005
        token_hash.each do |token, jid|
          result, status = get_final_results(token)
          if result
            node = Vertebra::JID.new(jid).node
            logger.debug "node #{node}\njid: #{jid}"
            token_hash.delete(token) if ['error', 'final'].include?(status)
            (results_hash[node] ||=[]) << result['response'] || result['backtrace']
          end
        end
      end
      results_hash
    end

    def wait_for_get_op(jid, op_type, args = {})
      gather(get_op(jid, op_type, args) => jid)
    end

    def wait_for_set_op(jid, op_type, args = {})
      gather(set_op(jid, op_type, args) => jid)
    end

    def scatter(jids, op_type, args = {})
      ids = {}
      jids.each do |jid|
        ids[get_op(jid, op_type, args)] = jid
      end
      ids
    end

    def send_operation(iq, threaded=true)
      sender = lambda do
        begin
          @client.send_with_id(iq) do |answer|
            if answer.type == :result
              queue(:received_results) << answer
            else
              queue(:received_error_results) << answer
            end
          end
        rescue Vertebra::JabberError => e
          result_iq = iq.answer(true)
          result_iq.type = :error
          result_iq.add(e.error)
          queue(:received_error_results) << result_iq
        end
      end
      if threaded
        Thread.new{ sender.call }
      else
        sender.call
      end
    end

    def get_final_results(id)
      res = nil
      final_results do |iq|
        result = iq.first_element('result')
        if result.attributes['token'].split(':').first == id
          status = result.attributes['status']
          not_authed = REXML::XPath.first( result, "//not-authorized" )
          res = [not_authed ? {'response' => 'NOT AUTHORIZED'} : Vertebra::Marshal.decode(iq.first_element('result')), status]
        else
          queue(:final_results) << iq
        end
      end
      res
    end

    # override agent message handler, use growl instead
    def handle_message(msg)
      if msg.first_element('x').is_a? Jabber::MUC::XMUCUser
        handle_invite(msg)
      else
        logger.debug msg.inspect
        notify(msg.body, msg.from.to_s)
      end
    end

  end # InterfaceAgent

end # Vertebra
