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

module LM
  class Attributes

    def initialize(node)
      @node = node
    end

    def [](name)
      @node.get_attribute(name)
    end
  end

  class Message
    def type
      self.root_node.get_attribute('type').to_sym
    end

    def from
      self.root_node.get_attribute('from ')
    end
  end

  class MessageNode
    alias :_add_child :add_child

    # This enables #add_child to add either REXML elements or LoudMouth elements.
    # The REXML elements are converted to LoudMouth elements.

    def add_child(child)
      if Object.const_defined?(:REXML) && REXML::Element === child
        _add_child(child.name)
        lm_child = get_last_child(child.name)
        child.attributes.each { |k,v| lm_child.set_attribute(k,v) }
        child_text = child.text.to_s.strip
        lm_child.value = child_text.empty? ? nil : child_text
        child.each_element { |element| lm_child.add_child(element) }
      else
        _add_child(child)
      end
    end

    def get_last_child(name)
      last_child = next_child = get_child(name)
      while next_child = next_child.next
        last_child = next_child if next_child.name == name
      end

      last_child
    end

    def attributes
      LM::Attributes.new(self)
    end
    def [](attr)
      get_attribute(attr)
    end

    def []=(attr,val)
      set_attribute(attr,val)
    end

    alias :child :children
  end
end
