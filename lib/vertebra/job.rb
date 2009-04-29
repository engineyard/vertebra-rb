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

  class Job
    attr_accessor :finished

    def initialize(operation, token, scope, from, to, outcall_or_agent, args)
      @finished = false
      @seq = 0
      @operation, @token, @scope, @from, @to, @outcall_or_agent, @args = operation, token, scope, from, to, outcall_or_agent, args
    end
    attr_reader :operation, :scope, :from, :to, :args
    attr_accessor :token

    def update_token(new_token)
      raise ArgumentError, "Token cannot be updated to #{new_token}, it has already been updated once" if @updated
      @updated = true
      @token = new_token
    end

    # Use this to return a single result, which will in turn cause a single <data>
    # stanza to be sent back to the client.  This allows sending of partial results
    # over time, or streaming of data.
    def result(data)
      wrapped_data = {'_partial_data' => data, '_seq' => @seq}
      @seq += 1

      begin
      result_tag = Vertebra::Data.new(@token, wrapped_data)
      result_iq = result_tag.to_iq
      result_iq.node['to'] = from
      @outcall_or_agent.servers[token].final_countdown[result_iq.node['id']] = true
      @outcall_or_agent.packet_memory.set(result_iq.node['to'], token, result_iq.node['id'],result_iq)
      @outcall_or_agent.send_iq(result_iq)
      rescue Exception => e
        puts e; puts e.backtrace
      end

    end

    def finished?
      @finished
    end

  end
end
