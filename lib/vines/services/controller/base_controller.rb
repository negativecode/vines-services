# encoding: UTF-8

module Vines
  module Services
    module Controller
      class BaseController
        include Vines::Log
        include CouchModels
        include Nokogiri::XML

        def self.register(*args)
          Connection.register(*args, self)
        end

        attr_reader :storage, :node, :stream, :uploads

        def initialize(node, stream, vhost)
          @node, @stream, @storage = node, stream, vhost.storage
          @uploads = vhost.uploads
          @current_user = nil
        end

        def process
          # must be addressed to component, not a service
          return unless to_component?
          if node.get?
            get
          elsif node.set? && node.elements.first['action'] == 'delete'
            delete
          elsif node.set?
            save
          end
        rescue Forbidden
          raise
        rescue
          send_error('not-acceptable')
        end

        private

        def get
          send_error('feature-not-implemented')
        end

        def save
          send_error('feature-not-implemented')
        end

        def delete
          send_error('feature-not-implemented')
        end

        def send_result(obj=nil)
          iq = Blather::Stanza::Iq::Query.new(:result).tap do |result|
            result.id, result.to, result.from = node.id, node.from, node.to
            result.query.content = obj.to_json if obj
            result.query.namespace = node.elements.first.namespace.href
          end
          stream.write(iq)
        end

        def send_error(condition, obj=nil)
          err = Blather::StanzaError.new(node, condition, :modify).tap do |error|
            error.extras << Blather::XMPPNode.new('vines-error').tap do |verr|
              verr.namespace = 'http://getvines.com/error'
              verr.content = obj.to_json
            end if obj
          end
          stream.write(err.to_node)
        end

        def send_doc(doc)
          if doc
            send_result(doc.to_result)
          else
            send_error('item-not-found')
          end
        end

        # Return true if the stanza is addressed to the component's JID rather
        # than to a service JID.
        def to_component?
          node.to == stream.jid
        end

        def forbidden!
          raise Forbidden
        end

        # Return the User object for the user that sent this stanza. Useful for
        # permission authorization checks before performing server actions.
        def current_user
          jid = node.from.stripped.to_s.downcase
          @current_user ||= User.find_by_jid(jid)
        end
      end
    end
  end
end
