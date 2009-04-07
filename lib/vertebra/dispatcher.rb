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

require 'vertebra/resource'

module Vertebra
  class Dispatcher
    attr_reader :actors, :deployment_resources, :agent

    def initialize(agent, deployment_resources)
      @agent = agent
      @actors = []
      @deployment_resources = deployment_resources
    end

    def register(actors)
      registered = []
      actors.each do |actor, actor_config|
        begin
          logger.debug "Requiring #{actor.to_s} from paths #{$:.inspect}"
          require actor.to_s
        rescue LoadError => e
          logger.debug "Could not require #{actor.to_s}. Please verify that it is installed under that name."
          logger.debug e.message
        end

        begin
          actor_name = actor.to_s.constantcase
          actor_class = Vertebra::Utils.constant(actor_name)
          logger.debug "Registering #{actor_name} as #{actor_class}"
          @actors << actor_class.new(@agent, @deployment_resources, actor_config)
          registered << actor_name
        rescue => e
          logger.debug "Instantiation of actor #{actor.to_s.constantcase} failed; please confirm that the actor class that is desired carries this name."
          logger.debug e.message
          logger.debug e.backtrace.join("\n")
        end
      end

      registered
    end

    def candidates(operation, args)
      logger.debug "in candidates (#{operation}) -- args: #{args.inspect}"
      resources = Vertebra::Utils.resources_from_args(args)

      logger.debug "RESOURCES: #{resources.inspect}"

      actors.select do |actor|
        actor.providing_operation?(operation) && actor.providing_resources?(resources)
      end
    end

    # handle takes an <op>eration, decodes the arguments to a ruby hash
    # and then figures out which actors to call, then yields a tuple of
    # [results, true] where true means the final response. Each actors's
    # response will be yielded and the boolean flag is used to mean 'this
    # is the last result'. If no actors can service the operation, we return
    # a <nil> result marked as final.
    def handle(job)
      logger.debug "Dispatcher handling #{job}"
      actors = candidates(job.operation, job.args)
      logger.debug "Found #{actors.size} candidate actors"
      logger.debug "SCOPE: #{job.scope.inspect}"

      # Dispatched ops is an array of synapses which are each gathering the
      # results from the method dispatches they are responsible for.
      dispatched_ops = []

      actors.each do |actor|
        dispatched_ops << actor.handle(job)
      end

      ops_bucket = Vertebra::Synapse.new
      logger.debug "Ops Bucket: #{dispatched_ops.inspect}"

      ops_bucket.condition do
        dispatched_ops.all? do |gatherer|
          gatherer.has_key?(:results)
        end ? :succeeded : :deferred
      end

      ops_bucket.callback do
        ops_bucket[:results] = []
        dispatched_ops.each do |gatherer|
          res = gatherer[:results]
          logger.debug "RESPONSE #{res.inspect}"
          res.each {|r| ops_bucket[:results] << r }
        end
      end

      @agent.do_or_enqueue_synapse(ops_bucket)
      ops_bucket
    end

    def logger
      Vertebra.logger
    end
  end
end
