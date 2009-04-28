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

module Vertebra
  class Outcall
    def self.start(agent, operation, token, scope, args, jids)
      new(agent, operation, token, scope, args, jids).start
    end

    def initialize(agent, operation, token, scope, args, jids)
      raise ArgumentError, "#{args.inspect} is not a Hash" unless args.is_a?(Hash)
      @agent, @operation, @token, @scope, @args, @jids = agent, operation, token, scope, args, jids
    end

    def start
      case @scope
      when :direct, :single, :all
        discoverer = Vertebra::Synapse.new
        discoverer.callback do
          discover do |jids|
            if jids.nil? || jids.empty?
              discoverer[:results] = []
            elsif @scope == :all
              gather(discoverer, jids)
            else
              gather_one(discoverer, jids.sort_by { rand })
            end
          end
        end
        @agent.do_or_enqueue_synapse(discoverer)

        discoverer
      else
        raise ArgumentError, "The scope #{@scope.inspect} is not valid"
      end
    end

    def gather(discoverer, jids)
      ops = scatter(jids)

      gatherer = Vertebra::Synapse.new
      gatherer.condition do
        num_finished = 0

        ops.each { |jid, client| num_finished += 1 if client.done? }
        num_finished == ops.size ? :succeeded : :deferred
      end
      gatherer.callback do
        results = []
        ops.each { |jid, client| results << client.results unless client.results.empty? }
        discoverer[:results] = results
      end
      enqueue_synapse(gatherer)
    end

    # This method queue an op for each jid, and returns a hash containing the
    # client protocol object for each.
    def scatter(jids)
      ops = {}
      jids.each do |jid|
        logger.debug "scatter# #{@token} #{@operation} | #{jid} | #{@args.inspect}"
        ops[jid] = raw_op(@operation, jid, @args)
      end
      ops
    end

    def gather_one(discoverer, jids)
      nexter = Vertebra::Synapse.new
      jid = jids.shift
      op = raw_op(@operation, jid, @args)
      nexter.condition do
        op.done? ? :succeeded : :deferred
      end

      nexter.callback do
        if op.state == :commit
          discoverer[:results] = op.results
        else
          # The client is done, but it is not in :commit state, so it failed.
          # If there are other jids to try, do so.
          if jids.length > 0
            gather_one(discoverer, jids, operation, entree)
          else
            # There were no other jids to try, so we're out of targets, and have
            # no results; this returns an error.
            # Clarify: Should the code do this, or should it return an array
            # of ALL of the errors that were received?
            discoverer[:results] = [:error, "Operation Failed"]
          end
        end
      end

      @agent.enqueue_synapse(nexter)
    end

    # #discover takes as args a list of resources either in string form
    # (/foo/bar) or as instances of Vertebra::Resource.  It returns a list
    # of jids that will handle any of the resources.
    def discover(&block)
      if @scope == :direct
        yield @jids
        return
      end

      resources = Vertebra::Utils.resources_from_args(@args)
      discover_args = {"job" => {"operation" => @operation, "resources" => resources}}

      logger.debug "DISCOVERING: #{discover_args.inspect} on #{@agent.herault_jid}"
      client = raw_op('/security/discover', @agent.herault_jid, discover_args)
      requestor = Vertebra::Synapse.new
      requestor.condition do
        client.done? ? :succeeded : :deferred
      end
      requestor.callback do
        unless client.results.empty?
          agent_jid = @agent.jid.to_s
          yield client.results['jids'].select {|jid| jid != agent_jid}
        else
          yield []
        end
      end
      @agent.enqueue_synapse(requestor)
    end

    def raw_op(operation, to, args)
      Vertebra::Protocol::Client.start(self, operation, @token, @scope, to, args)
    end

    def logger
      Vertebra.logger
    end

    # TODO: These method are proxying through to the Agent instance
    # They are here to show what parts of the API need to be rethought
    def jid(*args)
      @agent.jid(*args)
    end

    def add_client(*args)
      @agent.add_client(*args)
    end

    def remove_client(*args)
      @agent.remove_client(*args)
    end

    def enqueue_synapse(*args)
      @agent.enqueue_synapse(*args)
    end

    def do_or_enqueue_synapse(*args)
      @agent.do_or_enqueue_synapse(*args)
    end

    def connection_is_open_and_authenticated?(*args)
      @agent.connection_is_open_and_authenticated?(*args)
    end

    def servers
      @agent.servers
    end

    def send_iq(*args)
      @agent.send_iq(*args)
    end

    def send_result(jid, id, attributes = {}, &block)
      @agent.send_result(jid, id, attributes, block)
    end

    def packet_memory(*args)
      @agent.packet_memory(*args)
    end

  end
end
