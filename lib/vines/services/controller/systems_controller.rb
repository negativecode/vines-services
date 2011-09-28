# encoding: UTF-8

module Vines
  module Services
    module Controller
      class SystemsController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/systems'

        private

        def get
          if name = node.elements.first['name']
            forbidden! unless current_user.manage_systems? || from_system?(name)
            send_doc(System.find_by_name(name))
          else
            forbidden! unless current_user.manage_systems?
            send_result(rows: System.find_all)
          end
        end

        # Agents are allowed to save system data for their machine only. No
        # other user may change a system's description.
        def save
          obj = JSON.parse(node.elements.first.content)
          fqdn = obj['fqdn'].downcase
          forbidden! unless from_system?(fqdn)

          id = "system:#{fqdn}"
          system = System.find(id) || System.new(id: id)
          system.ohai = obj
          system.save
          storage.index(system)
          System.notify_members(stream, node.from, [{'name' => fqdn}])
          send_result
        end

        # Return true if a System user is requesting access to its own data.
        def from_system?(fqdn)
          current_user.system? && node.from.node.downcase == fqdn.downcase
        end
      end
    end
  end
end
