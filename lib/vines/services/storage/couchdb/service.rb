# encoding: UTF-8

module Vines
  module Services
    module CouchModels
      class Service < CouchRest::Model::Base
        extend Storage::CouchDB::ClassMethods

        KEYS      = %w[_id name code accounts users jid created_at modified_at].freeze
        VIEW_ID   = "_design/System".freeze
        VIEW_NAME = "System/memberships".freeze

        attr_writer :size

        after_save :update_views
        after_destroy :update_views

        property :name, String
        property :code, String
        property :accounts, [String], :default => []
        property :users, [String], :default => []
        property :jid, String

        timestamps!

        validates_uniqueness_of :name
        validates_presence_of :name
        validates_presence_of :code
        validates_uniqueness_of :jid
        validates_presence_of :jid
        validate :compile_view

        design do
          view :by_name,
            map: %q{
              function(doc) {
                if (doc.type != 'Service' || !doc.name) return;
                emit(doc.name, doc);
              }
            }

          view :by_jid,
            map: %q{
              function(doc) {
                if (doc.type != 'Service' || !doc.jid) return;
                emit(doc.jid, doc);
              }
            }

          view :by_account,
            map: %q{
              function(doc) {
                if (doc.type != 'Service' || !doc.accounts) return;
                doc.accounts.forEach(function(account) {
                  emit(account, doc);
                });
              }
            },
            reduce: '_count'

          view :by_user,
            map: %q{
              function(doc) {
                if (doc.type != 'Service' || !doc.users) return;
                doc.users.forEach(function(jid) {
                  emit(jid, doc);
                });
              }
            },
            reduce: '_count'
        end

        # Return true if this JID is allowed access to this service.
        def user?(jid)
          users.include?(jid.to_s.downcase)
        end

        # Allow the user, specified by their JID, to access the members of this
        # service. Adds the JID to the list and ensures the list stays sorted
        # and unique.
        def add_user(jid)
          users << jid.to_s.downcase
          users.sort!
          users.uniq!
        end

        # Remove this user's permission to access this service.
        def remove_user(jid)
          users.delete(jid.to_s.downcase)
        end

        # Return the number of members in this service's view. This is faster
        # than calling Service#members#size because this reduces the view,
        # so all members aren't loaded from the database. The size is cached so
        # subsequent calls to this method do not query the view.
        def size
          unless @size
            rows = database.view(VIEW_NAME, reduce: true, key: [0, id])['rows'] rescue []
            @size = rows.first ? rows.first['value'] : 0
          end
          @size
        end

        # Query the members view and return an Array of Hashes like this:
        # [{name: 'www.wonderland.lit', os: 'linux'}]. The members are cached
        # so subsequent calls to this method do not query the view.
        def members
          unless @members
            rows = database.view(VIEW_NAME, reduce: false, key: [0, id])['rows'] rescue []
            @members = rows.map {|row| row['value'] }
          end
          @members
        end

        def to_result
          to_hash.clone.keep_if {|k, v| KEYS.include?(k) }
            .tap {|h| h['id'] = h.delete('_id') }
        end

        def self.find_by_name(name)
          first_from_view('by_name', name)
        end

        def self.find_by_jid(jid)
          first_from_view('by_jid', jid.to_s.downcase)
        end

        def self.find_by_user(jid)
          by_user.key(jid.to_s.downcase).to_a
        end

        def self.find_all
          sizes = find_sizes
          by_name.map do |doc|
            doc.size = sizes[doc.id] || 0
            doc
          end
        end

        # Return a Hash of service ID to member count.
        def self.find_sizes
          {}.tap do |hash|
            rows = database.view(VIEW_NAME, reduce: true, group: true, startkey: [0], endkey: [1])['rows'] rescue []
            rows.each do |row|
              hash[row['key'][1]] = row['value']
            end
          end
        end

        private

        def compile_view
          VQL::Compiler.new.to_js(code)
        rescue Exception => e
          errors.add(:base, e.message)
        end

        def update_views
          js = VQL::Compiler.new.to_full_js(self.class.by_name.to_a)
          design = database.get(VIEW_ID) rescue nil
          design ||= {'_id' => VIEW_ID, 'views' => {}}
          design['views']['memberships'] = {map: js, reduce: '_count'}
          database.save_doc(design)
          # trigger view update, discard results
          EM::HttpRequest.new("#{database.root}/#{VIEW_ID}/_view/memberships").get
        end
      end
    end
  end
end
