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

require 'loudmouth'

module Vertebra
  class BaseElement < Jabber::XMPPElement
    def initialize(token = nil)
      super()
      add_attribute('token', token)
    end

    def token
      attributes['token']
    end
    
    def to_iq(from = '')
      iq = LM::Message.new(from, LM::MessageType::IQ, LM::MessageSubType::SET)
      iq.node.raw_mode = false
      iq.node.add_child self
      iq
    end

  end

  class Ack < BaseElement
    name_xmlns 'ack', 'http://xmlschema.engineyard.com/agent/api'
    force_xmlns true
  end

  class Nack < BaseElement
    name_xmlns 'nack', 'http://xmlschema.engineyard.com/agent/api'
    force_xmlns true
  end

  class Final < BaseElement
    name_xmlns 'final', 'http://xmlschema.engineyard.com/agent/api'
    force_xmlns true
  end

  class Data < BaseElement
    name_xmlns 'data', 'http://xmlschema.engineyard.com/agent/api'
  end

  class Error < BaseElement
    name_xmlns 'error', 'http://xmlschema.engineyard.com/agent/api'
  end

  class Init < BaseElement
    name_xmlns 'op', 'http://xmlschema.engineyard.com/agent/api'
    force_xmlns true

    def initialize(token, type, scope)
      super(token)
      add_attribute('scope', scope.to_s)
      add_attribute('type', type.to_s)
    end

    def type
      attributes['type']
    end
  end
end
