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
  class Op

    def initialize(op_type, *args)
      params = args.pop if args.last.is_a? Hash
      hsh = {}
      args.each do |arg|
        hsh[arg] = res(arg)
      end

      # if the last resource is a hash, it's assumed that it's an argument hash
      hsh.merge!(params) if params
      @args = hsh
      @op_type = Vertebra::Resource.new(op_type.to_s)
    end

    def to_iq(to, from, type=LM::MessageSubType::SET)
      iq = LM::Message.new(to, LM::MessageType::IQ,type)
      #iq.node.set_attribute('from',from.to_s)
      op = Vertebra::Operation.new(@op_type, Vertebra.gen_token)

      iq.node.set_attribute('xml:lang','en')
      iq.node.add_child op
      op_lm = iq.node.get_child(op.name)

      Vertebra::Marshal.encode(@args).children.each do |el|
        op_lm.add_child el
      end
      logger.debug "CREATED IQ #{iq.node.to_s} with class #{iq.class}"
      iq
    end

  end

end
