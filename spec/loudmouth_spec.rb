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

require File.dirname(__FILE__) + '/spec_helper'
require 'loudmouth'
require 'vertebra/loudmouth_extension'
require 'rexml/element'
require 'rexml/document'

describe "LoudMouth & Extensions" do

  it 'should have the ability to create messages with a tree of XML elements' do
    lm = LM::Message.new('test@jid',LM::MessageType::IQ)
    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+"><\/iq>/)

    lm.node.add_child('string')
    lm_string = lm.node.get_child('string')
    lm_string.value = 'abc123'
    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+">\s*<string>abc123<\/string>/)

    lm.node.add_child('string')
    lm_string2 = lm_string.next
    lm_string2.value = 'quasimoto'
    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+">\s*<string>abc123<\/string>\s*<string>quasimoto<\/string>/)
  end

  it 'should allow messages to be built from simple REXML elements' do
    lm = LM::Message.new('test@jid',LM::MessageType::IQ)
    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+"><\/iq>/)

    re = REXML::Element.new('poem')
    re.text = 'hear the sledges with the bells'
    re.add_attribute('author','Edgar Allen Poe')

    lm.node.add_child re
    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+">\s*<poem author="Edgar Allen Poe">hear the sledges with the bells<\/poem>/)
  end

  it 'should allow messages to be built from complex, nested REXML elements' do
    lm = LM::Message.new('test@jid',LM::MessageType::IQ)
    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+"><\/iq>/)

    book_e = REXML::Element.new('book')
    book_e.add_attribute('title','Cool Stuff')

    re = REXML::Element.new('poem')
    re.text = 'hear the sledges with the bells'
    re.add_attribute('author','Edgar Allen Poe')

    book_e.add_element re

    re = REXML::Element.new('poem')
    re.text = 'I was a child, and she was a child, in this kingdom by the sea, and we loved with a love that was more than a love....'
    re.add_attribute('author','Edgar Allen Poe')

    book_e.add_element re

    re = REXML::Element.new('poem')
    re.text = 'Mary had a little lamb....'
    re.add_attribute('author','Unknown')

    book_e.add_element re
    lm.node.add_child book_e

    lm.node.to_s.should match(/<iq type="get" to="test@jid" id="\d+">\s*<book title="Cool Stuff">\s*<poem author="Edgar Allen Poe">hear the sledges with the bells<\/poem>\s*<poem author="Edgar Allen Poe">I was a child, and she was a child, in this kingdom by the sea, and we loved with a love that was more than a love....<\/poem>\s*<poem author="Unknown">Mary had a little lamb....<\/poem>[\s\n]*<\/book>[\s\n]*<\/iq>/)
  end

end
