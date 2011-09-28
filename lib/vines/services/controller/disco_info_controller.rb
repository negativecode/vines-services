# encoding: UTF-8

module Vines
  module Services
    module Controller
      class DiscoInfoController < BaseController
        register :disco_info, :get?

        def process
          reply = (node.to == stream.jid) ? component : service
          stream.write(reply) if reply
        end

        private

        # Return the discovery reply node for a query addressed to the
        # component JID itself (e.g. vines.wonderland.lit), rather than to a
        # service JID. Advertise the http://getvines.com/protocol feature
        # so agents can discover the component JID with which to communicate.
        def component
          disco_node.tap do |disco|
            disco.identities = {
              name: 'Vines Services',
              type: 'bot',
              category: 'component'
            }
            disco.features = %w[
              http://jabber.org/protocol/bytestreams
              http://jabber.org/protocol/disco#info
              http://jabber.org/protocol/si
              http://jabber.org/protocol/si/profile/file-transfer
              http://jabber.org/protocol/xhtml-im
              http://getvines.com/protocol
              jabber:iq:version
            ]
          end
        end

        # Return the discovery reply node for a query addressed to a service
        # JID (e.g. web_servers@vines.wonderland.lit). Ignore, rather than send
        # an error, for queries to service JID's that don't exist or to which
        # the user doesn't have access.
        def service
          found = Service.find_by_jid(node.to.to_s)
          return unless found && found.users.include?(node.from.stripped.to_s)
          disco_node.tap do |disco|
            disco.features = %w[http://jabber.org/protocol/xhtml-im]
          end
        end

        def disco_node
          Blather::Stanza::DiscoInfo.new(:result).tap do |disco|
            disco.id = node.id
            disco.to = node.from
            disco.from = node.to
          end
        end
      end
    end
  end
end
