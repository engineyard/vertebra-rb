# This is generated code.  You should replace this with a copyright statement
# and licensing information.

require 'vertebra/actor'

#####
#
# This file is where you want to insert the code for your operations.  Flesh
# out the method stubs below.
#
#####

module <%= @config[:class_name] %>
  class Actor < Vertebra::Actor

<%= provides = ''; @config[:resources].each {|res| provides << "    provides '#{res}' # The resource that this actor is providing.\n"}; provides %>

<%=
      r = ''
      @config[:operations].each do |op|
        meth_name = op.tr('/','_')[1..-1]

        r << <<EMETHODS
    bind_op "#{op}"
    desc "#{op} action description"
    #method_options :param1 => :optional, :param2 => :required
    def #{meth_name}(options = {}, job)
    end

EMETHODS
      end
      r
%>

  end
end
