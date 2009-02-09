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
  class ClientAPI
    attr_accessor :handle

    def initialize(handle)
      @handle = handle
    end

    # #discover takes as args a list of resources either
    # in string form (/foo/bar) or as instances of
    # Vertebra::Resource.  It returns a list of jids that
    # will handle any of the resources.
    def discover(*resources)
      op('/security/discover',
         @handle.herault_jid,
         *resources.collect do |r|
        Vertebra::Resource === r ? r.to_s : r
         end)
    end

    def direct_op(op_type, to, *args)
      @handle.direct_op(op_type, to, *args)
    end

    def op(op_type, to, *args)
      client = direct_op(op_type, to, *args)
      while !(z = client.done?)
        sleep 0.05
      end
      client.results
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

      if jids.empty?
        []
      elsif scope == :all
        gather(scatter(target_jids, op_type, *cooked_args))
      else
        # FIXME
        gather(scatter(target_jids.sort_by { rand }.first, op_type, *cooked_args), true)
      end
    end


    def scatter(jids, op_type, *args)
      ops = {}
      jids.each do |jid|
        ops[jid] = direct_op(op_type, jid, *args)
      end
      ops
    end

    def gather(ops={}, single_scope = false)
      results = []
      while ops.size > 0 do
        ops.each do |jid, client|
          if client.done?
            results << client.results unless client.results.empty?
            ops.delete(jid)
            break if single_scope
          end
        end
        break if single_scope and results.size > 0
        sleep(0.05)
      end
      single_scope ? results.first : results
    end

    def advertise_op(resources, ttl = @handle.ttl)
      client = @handle.direct_op('/security/advertise',
                                 @handle.herault_jid,
                                 :resources => resources,
                                 :ttl => ttl
                                )

                                while !(z = client.done?)
                                  sleep 0.05
                                end
    end

    def unadvertise_op(resources)
      advertise_op(resources,0)
    end

  end
end
