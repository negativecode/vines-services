# encoding: UTF-8

module Vines
  module Services
    module Controller
      # Reply to presence probes if the user has privilege to access the
      # requested service JID. Reply to all probes to the component itself.
      class ProbesController < BaseController
        register :presence, :probe?

        def process
          from, to = node.from.stripped, node.to.stripped
          if approved?
            stream.write(available(to, from))
          else
            stream.write(unsubscribed(to, from))
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

        def unsubscribed(from, to)
          Blather::Stanza::Presence::Subscription.new.tap do |stanza|
            stanza.type = :unsubscribed
            stanza.from = from
            stanza.to = to
          end
        end
      end
    end
  end
end
