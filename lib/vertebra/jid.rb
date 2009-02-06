# This is from XMPP4R, slightly modified and cleaned up.
#
# =XMPP4R - XMPP Library for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/xmpp4r/

module Vertebra
  class JID
    include Comparable

    PATTERN = /^(?:([^@]*)@)??([^@\/]*)(?:\/(.*?))?$/

    def initialize(node = "", domain = nil, resource = nil)
      @resource = resource
      @domain = domain
      @node = node
      @node, @domain, @resource = @node.to_s.scan(PATTERN).first if @domain.nil? and @resource.nil? and @node

      @node.downcase! if @node
      @domain.downcase! if @domain

      raise ArgumentError, 'Node too long' if (@node || '').length > 1023
      raise ArgumentError, 'Domain too long' if (@domain || '').length > 1023
      raise ArgumentError, 'Resource too long' if (@resource || '').length > 1023
    end

    def to_s
      s = @domain
      s = "#{@node}@#{s}" if @node
      s += "/#{@resource}" if @resource
      s
    end

    def strip; JID.new(@node, @domain); end
    alias_method :bare, :strip

    def strip!
      @resource = nil
      self
    end
    alias_method :bare!, :strip!

    def hash;return to_s.hash;end

    def eql?(o); to_s.eql?(o.to_s); end

    def ==(o); to_s == o.to_s; end

    def <=>(o); to_s <=> o.to_s; end

    def node; @node; end

    def node=(v); @node = v.to_s; end

    def domain
      @domain.empty? ? nil : @domain
    end

    def domain=(v); @domain = v.to_s; end

    def resource; @resource; end

    def resource=(v); @resource = v.to_s; end

    def JID::escape(jid); jid.to_s.gsub(/@/, '%'); end

    def empty?; to_s.empty?; end

    def stripped?; @resource.nil?; end
    alias_method :bared?, :stripped?
  end
end
