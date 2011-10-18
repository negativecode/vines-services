# encoding: UTF-8

module Vines
  module Services
    module Controller
      class UsersController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/users'

        private

        # Returns user information to the client without the password. Passwords,
        # despite being securely hashed, must never be sent to client requests.
        def get
          if jid = node.elements.first['jid']
            user = User.find_by_jid(jid)
            forbidden! unless authorized?(user)
            send_doc(user)
          else
            users = User.find_all.select {|user| authorized?(user) }
            send_result(rows: users)
          end
        end

        # Save the user to the database. The password needs to be bcrypted
        # before it is stored. Empty passwords will not be saved.
        def save
          obj = JSON.parse(node.elements.first.content)
          forbidden! unless authorized?(obj)

          system = (obj['system'] == true)
          jid, name, username, password1, password2 =
            %w[jid name username password1 password2].map {|a| (obj[a] || '').strip }

          raise 'jid required' if jid.empty? && username.empty?

          user = if jid.empty? # new user
            id = "user:%s" % Vines::JID.new(username, node.from.domain)
            raise 'user already exists' if User.find(id)
            User.new(id: id).tap do |u|
              u.system = system
              u.plain_password = password1
            end
          else # existing user
            User.get!("user:%s" % Vines::JID.new(jid)).tap do |u|
              raise "record found, but is a #{u.system ? 'system' : 'user'}" unless u.system == system
              if system
                u.plain_password = password1 unless password1.empty?
              else # humans
                if u.jid == current_user.jid
                  u.change_password(password1, password2) unless password1.empty? || password2.empty?
                else
                  u.plain_password = password1 unless password1.empty?
                end
              end
            end
          end

          unless system
            user.name = name
            # users can't set their own permissions
            unless user.jid == current_user.jid
              user.permissions = obj['permissions']
            end
          end

          if user.valid?
            user.save
            save_services(user, obj['services'] || [])
            send_doc(user)
          else
            send_error('not-acceptable')
          end
        end

        # Return true if the user is allowed to view and save the system or
        # user object. Users with no permissions still have the right to update
        # their own user account.
        def authorized?(user)
          return false unless user
          user = user.to_result if user.respond_to?(:to_result)
          system = user['system'] || user[:system]
          jid = user['jid'] || user[:jid]
          return current_user.manage_systems? if system
          current_user.manage_users? || current_user.jid == jid
        end

        def save_services(user, services)
          return if user.system? || !user.manage_services?
          current = user.services.map {|s| s.id }
          members = []

          # delete missing services
          user.services.each do |service|
            if !services.include?(service.id)
              members << service.members
              service.remove_user(user.jid)
              service.save
            end
          end

          # add new services
          add = services.select {|id| !current.include?(id) }
          Service.all.keys(add).each do |service|
            members << service.members
            service.add_user(user.jid)
            service.save
          end

          System.notify_members(stream, node.from, members.flatten.uniq)
        end

        # Delete the user as defined by the id of the query stanza. Users may
        # not delete themselves.
        def delete
          jid = Vines::JID.new(node.elements.first['id']).bare
          raise 'jid required' if jid.empty?
          user = User.find("user:#{jid}")
          forbidden! unless authorized?(user) &&
            node.from.stripped.to_s != jid.to_s
          user.destroy
          send_result
        end
      end
    end
  end
end
