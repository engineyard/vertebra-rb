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

# This file is a reimplementation of xmpp4r's rexmladdons. As such, it depends
# on some parts of REXML.
	
require 'rexml/source'
require 'rexml/document'
require 'rexml/parsers/xpathparser'
	
$_VERBOSE = $VERBOSE
$VERBOSE = false
	
module REXML
	
	class Element

		def self.import(xmlelement)
			self.new(xmlelement.name).import(xmlelement)
		end
	
		def replace_element_text(elem, text)
			element = first_element(elem)
	
			unless element
				element = REXML::Element.new(elem)
				add_element(element)
			end
		
			element.text = text if text
		
			self
		end
		
		def first_element(element)
			elements.each(element) {|e| return e}
			nil
		end
		
		def first_element_text(element)
			first_element(element) ? el.text : nil
		end
		
		def typed_add(element); add(element); end
		
		def import(xmlelement)
			raise "Can't import an #{xmlelement.name} to a #{@name} !" if @name and @name != xmlelement.name
			add_attributes(xmlelement.attributes.clone)
			@context = xmlelement.context xmlelement.each do |e|
				case e
					when REXML::Element then typed_add(e.deep_clone)
					when REXML::Text then add_text(e.value)
					else add(e.clone)
				end
			end
			
			self
		end
		
		def delete_elements(element)
			while(delete_element(element)); end
		end
		
		def ==(o)
			self.kind_of?(REXML::Element) &&
			
			(o.kind_of?(REXML::Element) ? true :
	
				(o.kind_of?(String) ? lambda do
					begin
						o = REXML::Document.new(o).root
					rescue REXML::ParseException
						false
					end
				end.call : false)) &&
			
			name == o.name &&
			
			_attributes_match(self,o) &&
			
			_attributes_match(o,self) &&
			
			(children.each_with_index {|child,i| break false unless child == o.children[i]})
		end
		
		private
		
		def _attributes_match(a1,a2)
				a1.each_attribute do |attr|
						break false unless attr.value == a2.attributes[attr.name]
				end
		end
		
		public
		
	end # class Element
	
	class IOSource
		BaseCurrentLine = [0,0,'']
		def position; 0; end
		def current_line; BaseCurrentLine; end
	end
	
end
	
$VERBOSE = $_VERBOSE
	
