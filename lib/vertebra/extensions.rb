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

class String
  def camelcase(upcase_first_letter = true)
    return self if self == '' or (self =~ /^[A-Z]/ and self !~ /[_\s]/)
    parts = split(/[-_\s]/)
    str = String.new(([parts[0].to_s.downcase] + parts[1..-1].collect {|x| x.capitalize}).join)
    str[0] = str[0].chr.upcase if upcase_first_letter
    str
  end

  def camelcase!
    replace(camelCase)
  end

  def constantcase
    split(/\//).collect {|s| s.camelcase}.join('::')
  end

  def snakecase(group = true)
    return self unless self =~ %r/[A-Z\s]/
    reverse.scan(%r/[A-Z]+|[^A-Z]*[A-Z]+?|[^A-Z]+/).reverse.map{|word| word.reverse.downcase}.join('_').gsub(/\s/,'_').gsub(/\//,'::')
  end

  def snakecase!
    replace(snake_case)
  end
end

module Vertebra
  module Utils
    def constant(c)
      const_string = "#{c}"
      base = const_string.sub!(/^::/, '') ? Object : ( Module === self ? Object : self.class )
      const_string.split(/::/).each {|name| base = base.const_get(name)}
      base
    rescue
      nil
    end

    def resource(text)
      Resource.parse(text)
    end

    def resources_hash_from_args(type, args)
      data = {"resources" => {"type" => type, "args" => {}}}
      args.each do |key,value|
        data["resources"]["args"][key] = value if value.is_a?(Resource)
      end
      data
    end

    def find_resources(args)
      resources = []
      args.each do |key,value|
        resources << value if value.is_a?(Resource)
      end
      resources
    end

    def keys_to_symbols(hash)
      newhash = {}
      hash.each {|k,v| newhash[k.to_s.intern] = v}
      newhash
    end

    module_function :constant, :keys_to_symbols, :resource, :find_resources, :resources_hash_from_args
  end
end

module Process
 def self.is_running?(pid)
   begin
     return Process.getpgid(pid) != -1
   rescue Errno::ESRCH
     return false
   end
 end
end

class Hash
 # Return a new hash with all keys converted to symbols.
 def symbolize_keys
   inject({}) do |options, (key, value)|
     options[(key.to_sym rescue key) || key] = value
     options
   end
 end

 # Destructively convert all keys to symbols.
 def symbolize_keys!
   self.replace(self.symbolize_keys)
 end
end
