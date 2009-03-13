# This file is borrowed from XMPP4R, and has been streamlined a little bit.
#
# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

module Jabber

  class XMPPElement < REXML::Element
    @@name_xmlns_classes = {}
    @@force_xmlns = false

    def self.name_xmlns(name, xmlns=nil); @@name_xmlns_classes[[name, xmlns]] = self; end

    def self.force_xmlns(force); @@force_xmlns = force; end

    def self.force_xmlns?; @@force_xmlns; end

    def self.name_xmlns_for_class(klass)
      klass.ancestors.each do |klass1|
        @@name_xmlns_classes.each {|name_xmlns,k| return name_xmlns if klass1 == k }
      end

      raise NoNameXmlnsRegistered.new(klass)
    end

    def self.class_for_name_xmlns(name, xmlns)
      if @@name_xmlns_classes.has_key? [name, xmlns]
        @@name_xmlns_classes[[name, xmlns]]
      elsif @@name_xmlns_classes.has_key? [name, nil]
        @@name_xmlns_classes[[name, nil]]
      else
        REXML::Element
      end
    end

    def self.import(element)
      klass = class_for_name_xmlns(element.name, element.namespace)
      if klass != self and klass.ancestors.include?(self)
        klass.new.import(element)
      else
        self.new.import(element)
      end
    end

    def initialize(*arg)
      if arg.empty?
        name, xmlns = self.class::name_xmlns_for_class(self.class)
        super(name)
        add_namespace(xmlns) if self.class::force_xmlns?
      else
        super
      end
    end

    def typed_add(element)
      if element.kind_of? REXML::Element
        element_ns = (element.namespace.to_s == '') ? namespace : element.namespace

        klass = XMPPElement::class_for_name_xmlns(element.name, element_ns)
        element = klass.import(element) if klass != element.class
      end

      super(element)
    end

    def parent=(new_parent)
      add_namespace(parent.namespace('')) if parent and parent.namespace('') == namespace('') and attributes['xmlns'].nil?

      super

      delete_namespcae if new_parent and new_parent.namespace('') == namespace('')
    end

    def clone
      cloned = self.class.new
      cloned.add_attributes self.attributes.clone
      cloned.context = @context
      cloned
    end

    def xml_lang; attributes['xml:lang']; end

    def xml_lang=(l); attributes['xml:lang'] = l; end

    def set_xml_lang(l)
      self.xml_lang = l
      self
    end

  end
end
