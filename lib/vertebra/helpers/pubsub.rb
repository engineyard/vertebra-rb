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

module Vertebra
  module PubSubHelper

    # See http://www.xmpp.org/extensions/xep-0060.html#owner-create-and-configure
    DEFAULT_NODE_CONFIG = {
      "pubsub#title" => 'New Vertebra Node',
      # should events be sent?
      "pubsub#deliver_notifications" => '1',
      # should items' payloads be sent?
      "pubsub#deliver_payloads" => '1',
      # should items persist after delivery to all subscribers?
      "pubsub#persist_items" => '0',
      "pubsub#max_items" => '100000',
      "pubsub#access_model" => 'open',
      "pubsub#publish_model" => 'publishers',
      "pubsub#send_last_published_item" => 'on_sub',
      "pubsub#presence_based_delivery" => 'false',
      "pubsub#notify_config" => '0',
      "pubsub#notify_delete" => '0',
      "pubsub#notify_retract" => '0',
      "pubsub#max_payload_size" => '10240',
      "pubsub#type" => 'http://www.w3.org/2005/Atom',
      "pubsub#body_xslt" => 'http://jabxslt.jabberstudio.org/atom_body.xslt',
      }

    # publish data to a pubsub node

    def publish(node, contents, server = nil)
      item = Jabber::PubSub::Item.new
      item.text = contents
      logger.debug "PUBLISHING #{item.inspect}"
      pubsub(server).publish_item_to(node, item)
    end

    def subscribe(node, server = nil)
      pubsub(server).subscribe_to(node)
    end

    def unsubscribe(node, server = nil)
      pubsub(server).unsubscribe_from(node)
    end

    def handle_pubsub_event(event)
      event.payload.each do |items|
        # maybe a bug in ejabberd sends out a retract item all the time. we don't use retract so we ignore it
        next if items.first_element("retract")
        logger.debug "GOT PUBSUB ITEMS #{items.inspect}"
        text = items.collect{|i| i.text }.join("\n")
        notify(text, "Vertebra Alert")
      end
    end

    def create_vertebra_node(path, config = {})
      pubsub.create_node(path, Jabber::PubSub::NodeConfig(path, DEFAULT_NODE_CONFIG.merge(config)))
    end

    def create_collection_node(path)
      pubsub.create_node(path)
    end

    def pubsub(pubsubjid = nil)
      pubsubjid ||= "pubsub.#{@jid.domain}"
      @pubsub[pubsubjid] ||= Jabber::PubSub::ServiceHelper.new(@client,pubsubjid)
      @pubsub[pubsubjid]
    end

  end
end
