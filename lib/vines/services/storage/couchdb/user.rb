# encoding: UTF-8

module Vines
  module Services
    module CouchModels
      class User < CouchRest::Model::Base
        extend Storage::CouchDB::ClassMethods

        KEYS = %w[_id name permissions system created_at updated_at].freeze

        before_save :enforce_constraints
        after_destroy :remove_references

        property :name, String
        property :password, String
        property :roster, Hash, :default => {}
        property :permissions, Hash, :default => {}
        property :system, TrueClass, :default => false

        timestamps!

        validates_presence_of :password

        design do
          view :by_jid,
            map: %q{
              function(doc) {
                if (doc.type != 'User') return;
                emit(doc['_id'].replace('user:', ''), doc);
              }
            }

          view :subscribers,
            map: %q{
              function(doc) {
                if (doc.type != 'User' || !doc.roster) return;
                Object.keys(doc.roster).forEach(function(jid) {
                  emit(doc['_id'].replace('user:', ''), jid);
                });
              }
            },
            reduce: '_count'
        end

        %w[systems services users files].each do |name|
          define_method "manage_#{name}?" do
            !!read_attribute('permissions')[name]
          end
          define_method "manage_#{name}=" do |value|
            read_attribute('permissions')[name] = !!value
          end
        end

        def permissions=(perms)
          perms ||= {}
          self.manage_systems = perms['systems']
          self.manage_services = perms['services']
          self.manage_files = perms['files']
          self.manage_users = perms['users']
        end

        def password=(desired)
          desired = (desired || '').strip
          raise 'password too short' if desired.size < (system ? 128 : 8)
          write_attribute('password', BCrypt::Password.create(desired))
        end

        def change_password(previous, desired)
          hash = BCrypt::Password.new(password) rescue nil
          raise 'password failure' unless hash && hash == previous
          self.password = desired
        end

        def jid
          id ? id.sub('user:', '') : nil
        end

        # Query the Service/by_user view and return the Service objects to which
        # this User has access. The services are cached so subsequent calls to
        # this method do not query the view.
        def services
          @services ||= Service.find_by_user(jid)
        end

        def to_result
          to_hash.clone.keep_if {|k, v| KEYS.include?(k) }.tap do |h|
            h['jid'] = h.delete('_id').sub('user:', '')
            h['services'] = h['system'] ? []: services.map {|s| s.id }
          end
        end

        def self.find_all
          by_jid.map do |doc|
            {jid: doc.jid, name: doc.name, system: doc.system}
          end
        end

        def self.find_by_jid(jid)
          first_from_view('by_jid', jid.to_s.downcase)
        end

        private

        # System users are not allowed to manage any other objects.
        def enforce_constraints
          if system
            write_attribute('name', nil)
            write_attribute('permissions', {})
          end
        end

        # After the User document is deleted, remove references to the user from
        # related documents (rosters, services, vcards and XML fragments).
        def remove_references
          if card = Vcard.find("vcard:#{jid}")
            card.destroy
          end

          Fragment.by_jid.key(jid).each do |doc|
            doc.destroy
          end

          Service.find_by_user(jid).each do |service|
            service.remove_user(jid)
            service.save
          end

          jids = User.subscribers.key(jid).rows.map {|row| row['value'] }
          User.by_jid.keys(jids).each do |subscriber|
            subscriber.roster.delete(jid)
            subscriber.save
          end
        end
      end
    end
  end
end
