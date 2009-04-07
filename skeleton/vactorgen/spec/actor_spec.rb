# This is generated code.  You should replace this with a copyright statement
# and licensing information.

require File.dirname(__FILE__) + '/spec_helper'
#require 'vertebra'
require '<%= @config[:name] %>/actor'

describe <%= @config[:class_name] %>::Actor do

  before(:all) do
    @actor = <%= @config[:class_name] %>::Actor.new
  end

    <%=
      r = ''
      @config[:operations].each do |op|
        meth_name = op.tr('/','_')[1..-1]

        r << <<EMETHODS

  it '#{meth_name} should ...' do
  end
EMETHODS
      end
      r
    %>
end
