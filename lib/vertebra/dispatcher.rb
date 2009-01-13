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
    attr_accessor :actors, :default_resources, :agent

    def self.can_provide?(required_resources, provided_resources)
      results = []
      required_resources.each do |req|
        accepted = false
        provided_resources.each do |prov|
          if req >= prov
            accepted = true
            break
          end
        end
        results << accepted
      end
      results.all? {|r| r }
    end

    def initialize(agent, resources = [])
      @agent = agent
      @actors = []
      @default_resources = resources.map { |res| Vertebra::Resource.new(res) } if resources
    end

    def register(*actors)
      actors.flatten.each do |actor|
        begin
          logger.debug "Requiring #{actor.to_s} from paths #{$:.inspect}"
          require actor.to_s

        rescue LoadError => e
          logger.debug "Could not load the actor class at #{actor.to_s}. Is it installed as a gem?"
          logger.debug e.message
        else
          actor_class = constant(actor.to_s.constantcase)
          actor_instance = actor_class.new
          actor_instance.agent = @agent
          actor_instance.default_resources = @default_resources
          @actors << actor_instance
        end
      end
    end

    def candidates(args)
      logger.debug "in candidates args: #{args.inspect}"
      resources = args.select {|name, value| Vertebra::Resource === value}.
                       map{|_,value| value }

      actors = @actors.select {|actor| self.class.can_provide?(resources, actor.provides)}
      logger.debug "SELECTED ACTORS: #{actors.inspect}"
      actors
    end

    # handle takes an <op>eration, decodes the arguments to a ruby hash
    # and then figures out which actors to call, then yields a tuple of
    # [results, true] where true means the final response. Each actors's
    # response will be yielded and the boolean flag is used to mean 'this
    # is the last result'. If no actors can service the operation, we return
    # a <nil> result marked as final.
    def handle(op)
      logger.debug "Disptcher handling #{op}"
      args = Vertebra::Marshal.decode(op)
      actors = candidates(args)
      results_yielded = false
      yielder = Proc.new {|res| yield({:response => res}, false) }
      actors.each_with_index do |actor, index|
        # force response into a hash
        begin
          res = actor.handle_op(op.attributes['type'], args, &yielder)
        rescue NoMethodError
          # This actor should not be dispatched to for this operation
          next
        end
        logger.debug "RESPONSE #{res.inspect}"
        unless (Hash === res && res.key?(:response))
          res = { :response => res }
        end
        yield(res)
      end
    end
  end
end
