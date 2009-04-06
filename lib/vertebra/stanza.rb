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
  class Stanza
    def self.handle(agent, iq)
      jid = iq.node['from']
      id = iq.node['id']
      if jid && id
        child_node = agent.packet_memory.get_by_jid_and_id(jid,id)
        child_node_name = child_node.node.child.name if child_node
      end

      child_node_name ||= iq.node.child.name      
      
      klass = case child_node_name
      when 'session'
        Stanzas::Session
      when 'op'
        Stanzas::Init
      when 'ack'
        Stanzas::Ack
      when 'nack'
        Stanzas::Nack
      when 'data'
        Stanzas::Data
      when 'final'
        Stanzas::Final
      when 'error'
        Stanzas::Error
      else
        Vertebra.logger.error "Unknown child node: #{child_node_name}: #{iq.node}"
        agent.handle_unhandled(iq)
        return
      end

      klass.new(agent, iq).handle
    end

    def initialize(agent, iq)
      @agent, @iq = agent, iq
    end
    attr_reader :agent, :iq

    def handle
      case type
      when "set"
        handle_set
      when "result"
        handle_result
      else
        raise ArgumentError, "Unable to handle type: #{type.inspect}"
      end
    end

    def handle_set
      raise NotImplementedError, "Implemented #{self.class}#handle_set"
    end

    def handle_result
      raise NotImplementedError, "Implemented #{self.class}#handle_result"
    end

    def node
      @iq.node
    end

    def child_node
      node.child
    end

    def id
      node["id"]
    end

    def from
      node["from"]
    end

    def to
      node["to"]
    end

    def type
      node["type"]
    end

    def token
      (child_node && child_node["token"]) || @agent.packet_memory.get_by_jid_and_id(from, id).node.child["token"]
    end

    def logger
      Vertebra.logger
    end
  end
end
