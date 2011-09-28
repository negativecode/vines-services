# encoding: UTF-8

module Vines
  module Services
    module Controller
      # Presence subscription requests are approved if the user has privilege to
      # access the requested service JID. All subscriptions to the component
      # itself are approved.
      class SubscriptionsController < BaseController
        register :subscription, :request?

        def process
          if approved?
            from, to = node.from.stripped, node.to.stripped
            stream.write(node.approve!)
            stream.write(available(to, from))
          else
            stream.write(node.refuse!)
          end
        end

        private

        def approved?
          return true if to_component?
          found = Service.find_by_jid(node.to)
          found && found.user?(node.from.stripped)
        end

        def available(from, to)
          Blather::Stanza::Presence::Status.new.tap do |stanza|
            stanza.from = from
            stanza.to = to
          end
        end
      end
    end
  end
end
