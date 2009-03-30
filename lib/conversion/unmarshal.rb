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

require 'rexml/document'
require 'rexml/xpath'

module Vertebra
  module Marshal
    class << self

      def decode(message)
        hsh = {}
        if REXML::Element === message
          message.each do |el|
            next unless el.attributes['name']
            hsh[el.attributes['name']] = decode_element(el)
          end
        else
          child = message.child
          while child
            hsh[name] = decode_element(child) if name = child.get_attribute('name')
            child = child.next
          end
        end
        hsh
      end

      def decode_element(el)
        case el.name
        when "string"
          el.text
        when 'nil'
          nil
        when "res"
          resource(REXML::Element === el ? el.text : el.value)
        when "i4"
          el.text.to_i
        when "boolean"
          boolean(REXML::Element === el ? el.text : el.value)
        when "base64"
          base64(REXML::Element === el ? el.text : el.value)
        when "double"
          el.text.to_f
        when "dateTime.iso8601"
          dateTime(REXML::Element === el ? el.text : el.value)
        when "list"
          arr = []
          if REXML::Element === el
            el.each_element do |child|
              arr << decode_element(child)
            end
          else
            child = el.child
            while child
              arr << decode_element(child)
              child = child.next
            end
          end
          arr
        when "struct"
          hsh = {}
          if REXML::Element === el
            el.each_element do |child|
              hsh[child.attributes['name']] = decode_element(child)
            end
          else
            child = el.child
            while child
              hsh[child.attributes['name']] = decode_element(child)
              child = child.next
            end
          end
          hsh
        else
          raise "Unkown Type! name: #{el.name} el: #{el}"
        end
      end

      def boolean(str)
        case str
        when "0" then false
        when "1" then true
        else
          raise "RPC-value of type boolean is wrong"
        end
      end

      def resource(res)
        ::Vertebra::Resource.parse(res)
      end

      def dateTime(str)
        case str
        when /^(-?\d\d\d\d)-?(\d\d)-?(\d\d)T(\d\d):(\d\d):(\d\d)(?:Z|([+-])(\d\d):?(\d\d))?$/
          a = [$1, $2, $3, $4, $5, $6].collect{|i| i.to_i}
          if $7
            ofs = $8.to_i*3600 + $9.to_i*60
            ofs = -ofs if $7=='+'
            utc = Time.utc(a.reverse) + ofs
            a = [ utc.year, utc.month, utc.day, utc.hour, utc.min, utc.sec ]
          end
          Vertebra::DateTime.new(*a)
        when /^(-?\d\d)-?(\d\d)-?(\d\d)T(\d\d):(\d\d):(\d\d)(Z|([+-]\d\d):(\d\d))?$/
          a = [$1, $2, $3, $4, $5, $6].collect{|i| i.to_i}
          if a[0] < 70
            a[0] += 2000
          else
            a[0] += 1900
          end
          if $7
            ofs = $8.to_i*3600 + $9.to_i*60
            ofs = -ofs if $7=='+'
            utc = Time.utc(a.reverse) + ofs
            a = [ utc.year, utc.month, utc.day, utc.hour, utc.min, utc.sec ]
          end
          Vertebra::DateTime.new(*a)
        else
          raise "wrong dateTime.iso8601 format " + str
        end
      end

      def base64(str)
        Vertebra::Base64.decode(str)
      end

    end # class << self
  end # Marshal
end # Vertebra


