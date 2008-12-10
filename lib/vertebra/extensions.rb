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

class Array
  def in_groups_of(number, fill_with = nil, &block)
    collection = dup
    collection << fill_with until collection.size.modulo(number).zero?
    collection.each_slice(number, &block)
  end
end

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

module Kernel
  def res(resource)
    ::Vertebra::Resource.new(resource)
  end

  # This is inspired from the Kernel::constant method in Facets.  This version is faster,
  # and will return nil if the constant being searched for can not be found.

  def constant(c)
    const_string = "#{c}"
    base = const_string.sub!(/^::/, '') ? Object : ( Module === self ? self : self.class )
    const_string.split(/::/).each {|name| base = base.const_get(name)}
    base
  rescue
    nil
  end

end

class Class
  # Defines class-level and instance-level attribute reader.
  #
  # @param *syms<Array> Array of attributes to define reader for.
  # @return <Array[#to_s]> List of attributes that were made into cattr_readers
  #
  # @api public
  #
  # @todo Is this inconsistent in that it does not allow you to prevent
  #   an instance_reader via :instance_reader => false
  def cattr_reader(*syms)
    syms.flatten.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end

        def #{sym}
          @@#{sym}
        end
      EOS
    end
  end

  # Defines class-level (and optionally instance-level) attribute writer.
  #
  # @param <Array[*#to_s, Hash{:instance_writer => Boolean}]> Array of attributes to define writer for.
  # @option syms :instance_writer<Boolean> if true, instance-level attribute writer is defined.
  # @return <Array[#to_s]> List of attributes that were made into cattr_writers
  #
  # @api public
  def cattr_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.flatten.each do |sym|
      class_eval(<<-RUBY, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      RUBY

      unless options[:instance_writer] == false
        class_eval(<<-RUBY, __FILE__, __LINE__)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        RUBY
      end
    end
  end

  # Defines class-level (and optionally instance-level) attribute accessor.
  #
  # @param *syms<Array[*#to_s, Hash{:instance_writer => Boolean}]> Array of attributes to define accessor for.
  # @option syms :instance_writer<Boolean> if true, instance-level attribute writer is defined.
  # @return <Array[#to_s]> List of attributes that were made into accessors
  #
  # @api public
  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end

class Module
  # Defines class-level and instance-level attribute reader.
  #
  # @param *syms<Array> Array of attributes to define reader for.
  # @return <Array[#to_s]> List of attributes that were made into cattr_readers
  #
  # @api public
  #
  # @todo Is this inconsistent in that it does not allow you to prevent
  #   an instance_reader via :instance_reader => false
  def mattr_reader(*syms)
    syms.flatten.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end

        def #{sym}
          @@#{sym}
        end
      EOS
    end
  end

  # Defines module-level (and optionally instance-level) attribute writer.
  #
  # @param <Array[*#to_s, Hash{:instance_writer => Boolean}]> Array of attributes to define writer for.
  # @option syms :instance_writer<Boolean> if true, instance-level attribute writer is defined.
  # @return <Array[#to_s]> List of attributes that were made into cattr_writers
  #
  # @api public
  def mattr_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.flatten.each do |sym|
      class_eval(<<-RUBY, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      RUBY

      unless options[:instance_writer] == false
        class_eval(<<-RUBY, __FILE__, __LINE__)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        RUBY
      end
    end
  end

  # Defines class-level (and optionally instance-level) attribute accessor.
  #
  # @param *syms<Array[*#to_s, Hash{:instance_writer => Boolean}]> Array of attributes to define accessor for.
  # @option syms :instance_writer<Boolean> if true, instance-level attribute writer is defined.
  # @return <Array[#to_s]> List of attributes that were made into accessors
  #
  # @api public
  def mattr_accessor(*syms)
    mattr_reader(*syms)
    mattr_writer(*syms)
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

#module LM
#  class Attributes
#    
#    def initialize(node)
#      @node = node
#    end
#    
#    def [](name)
#      @node.get_attribute(name)
#    end
#  end
#  
#  class Message
#    def type
#      self.root_node.get_attribute('type').to_sym
#    end
#
#    def from
#      self.root_node.get_attribute('from ')
#    end
#  end
#  
#  class MessageNode
#
#    def attributes
#      LM::Attributes.new(self)
#    end
#
#    def [](name)
#      self.get_attribute(name)
#    end
#    
#  end
#end
