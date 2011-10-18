# encoding: UTF-8

module Vines
  module Services
    module Controller
      # Broadcast messages from a user to a group of systems (a.k.a. a service).
      # Responses from the agents are routed back through the component so the
      # user appears to be talking to just the service's JID, not each and every
      # agent that belongs to the service.
      class MessagesController < BaseController
        register :message, :chat?, :body

        NS = 'http://getvines.com/protocol'.freeze

        def process
          current_user.system? ? forward_to_user : forward_to_service
        end

        private

        # Forward the agent's response message to the user that sent it the
        # command. Tag the message with a jid element, identifying the agent
        # returning the command's output, like:
        # <jid xmlns="http://getvines.com/protocol">
        #   www01.wonderland.lit@wonderland.lit/vines
        # </jid>.
        def forward_to_user
          jid = node.xpath('/message/ns:jid', 'ns' => NS).first
          return unless jid
          agent = node.from
          node.from = node.to
          node.to = jid.content
          jid.content = agent
          stream.write(node)
        end

        # Forward the user's message to the members of the service. Tag the
        # message with a jid element, identifying the user executing the command,
        # like: <jid xmlns="http://getvines.com/protocol">alice@wonderland.lit/tea</jid>
        # When the agent receives a message from one of its services, it checks
        # this jid element for the user permissions with which to run the command.
        #
        # Ignore the message, rather than send an error, if the user lacks
        # privilege to access the service to avoid directory harvesting.
        def forward_to_service
          service = Service.find_by_jid(node.to.stripped)
          if service && service.user?(node.from.stripped)
            service.members.each do |member|
              to = Blather::JID.new(member['name'], node.from.domain)
              stream.write(create_message(to))
            end
          else
            log.warn("#{node.from} denied access to #{node.to}")
          end
        end

        # Copy the message's content into a new message destined for the given
        # agent JID. Identify this command/response exchange with the message's
        # thread value. Tag the message with a jid element, identifying the
        # original user that sent the command.
        def create_message(to)
          Blather::Stanza::Message.new(to, node.body).tap do |msg|
            msg.thread = node.thread || Kit.uuid
            msg.from = node.to
            msg << msg.document.create_element('jid', node.from, xmlns: NS)
          end
        end
      end
    end
  end
end
