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

require 'rexml/element'
require 'date'
require 'conversion/datetime'
require 'conversion/base64'
require 'vertebra/resource'
require 'vertebra/xmppelement'

# Vertebra::Marshal encapsulates the conversion of a variety of different class
# types into XML elements which can be sent as part of an XMPP exchange.

module Vertebra
  module Marshal
    class << self
      include REXML

      def encode(args)
        el = Element.new('args')
        args.each do |k,v|
          el << encode_pair(k,v)
        end
        el.root
      end

      def encode_pair(name, value)

        # TODO: If this is going to be called often, and especially if this
        # list grows, it may be worthwhile to explore replacing what could
        # become a very, very long case statement with something like a
        # dispatch table to get constant time performance.

        case value
        when Fixnum
          el = Element.new("i4")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value
          el

        when Process::Status
          el = Element.new('i4')
          el.attributes['name'] = name.to_s unless name.nil?
          el.text = value.exitstatus
          el

        when Bignum
          if value >= -(2**31) and value <= (2**31-1)
            el = Element.new("i4")
            el.attributes['name'] = name.to_s  unless name.nil?
            el.text = value
            el
          else
            raise "Bignum is too big! Must be signed 32-bit integer!"
          end

        when Vertebra::Resource
          el = Element.new("res")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value
          el

        when Array, Set
          el = Element.new("list")
          el.attributes['name'] = name.to_s  unless name.nil?
          value.each{|v| el << encode_pair(nil, v)}
          el

        when TrueClass, FalseClass
          el = Element.new("boolean")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value ? 1 : 0
          el

        when String, Symbol
          el = Element.new("string")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value
          el

        when Float
          el = Element.new("double")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value
          el

        when Struct
          el = Element.new("struct")
          el.attributes['name'] = name.to_s  unless name.nil?
          value.members.collect do |key|
            val = value[key]
            el << encode_pair(key, val)
          end
          el

        when Hash
          el = Element.new("struct")
          el.attributes['name'] = name.to_s  unless name.nil?
          value.collect do |key, val|
            el << encode_pair(key, val)
          end
          el

        when Time, Date, ::DateTime
          el = Element.new("dateTime.iso8601")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value.strftime("%Y%m%dT%H:%M:%S")
          el

        when Vertebra::DateTime
          el = Element.new("dateTime.iso8601")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = format("%.4d%02d%02dT%02d:%02d:%02d", *value.to_a)
          el

        when Vertebra::Base64
          el = Element.new("base64")
          el.attributes['name'] = name.to_s  unless name.nil?
          el.text = value.encoded
          el

        when NilClass
          el = Element.new("nil")
          el.attributes['name'] = name.to_s  unless name.nil?
          el

        when Exception
          el = Element.new('exception')
          el.attributes['name'] = name.to_s unless name.nil?
          el.add_element encode_pair('class',value.class.name)
          el.add_element encode_pair('message',value.message)
          el.add_element encode_pair('backtrace',value.backtrace)
          el
        else
          # It seems reasonable that if an object is not specially handled, and if it supports a to_s
          # method, it will just be treated as a string instead of throwing an exception.
          if value.respond_to?(:to_str)
            el = Element.new("string")
            el.attributes['name'] = name.to_s unless name.nil?
            el.text = value.to_str
            el
          else
            # The code knows of no way to encode the object, so throw an exception.
            raise "The param given can not be marshalled as an XML element:  #{value}"
          end
        end
      end
    end # class << self
  end # Marshal

end
