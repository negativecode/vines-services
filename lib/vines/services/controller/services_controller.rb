# encoding: UTF-8

module Vines
  module Services
    module Controller
      class ServicesController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/services'

        private

        def get
          forbidden! unless current_user.manage_services?

          if id = node.elements.first['id']
            send_doc(Service.find(id))
          elsif name = node.elements.first['name']
            send_doc(Service.find_by_name(name))
          else
            rows = Service.find_all.map do |doc|
              {id: doc.id, name: doc.name, size: doc.size}
            end
            send_result(rows: rows)
          end
        end

        def save
          forbidden! unless current_user.manage_services?

          obj = JSON.parse(node.elements.first.content)
          raise 'name required' unless obj['name']
          obj['jid'] = to_jid(obj['name'])
          obj['users'] = validate_users(obj['users'])

          begin
            compiled = VQL::Compiler.new.to_js(obj['code'])
          rescue Exception => e
            send_error('not-acceptable', {error: e.message})
            return
          end

          service = Service.find(obj['id']) || Service.new
          members = service.members
          if service.update_attributes(obj)
            send_result(service.to_result)
            members << Service.find(service.id).members
            System.notify_members(stream, node.from, members.flatten.uniq)
          else
            send_error('not-acceptable')
          end
        end

        # Ensure the JID's that are given access to this service actually exist
        # and are not system accounts. System users may never have access to
        # services. Return the list of JID's that pass validation.
        def validate_users(jids)
          return [] unless jids
          users = User.by_jid.keys(jids)
          users.map {|u| u.system? ? nil : u.jid }.compact
        end

        # Create a JID for the service from its given name so we can address
        # stanzas to the service.
        def to_jid(name)
          Blather::JID.new(CGI.escape(name), stream.jid.domain).to_s.downcase
        end

        def delete
          forbidden! unless current_user.manage_services?

          if service = Service.find(node.elements.first['id'])
            service.destroy
            send_result
          else
            send_error('item-not-found')
          end
        end
      end
    end
  end
end
