# encoding: UTF-8

module Vines
  module Services
    module CouchModels
      class System < CouchRest::Model::Base
        extend Storage::CouchDB::ClassMethods

        KEYS      = %w[_id ohai created_at modified_at].freeze
        VIEW_NAME = "System/memberships".freeze

        attr_writer :services

        property :ohai, Hash

        timestamps!

        validates_presence_of :ohai

        design do
          # System docs are large so don't include them in the view. Use
          # include_docs=true when querying the view, if the full document
          # is needed.
          view :by_name,
            map: %q{
              function(doc) {
                if (doc.type != 'System') return;
                emit(doc['_id'].replace('system:', ''), null);
              }
            }

          view :attributes,
            map: %q{
              function(doc) {
                if (doc.type != 'System' || !doc.ohai) return;
                Object.keys(doc.ohai).forEach(function(key) {
                  emit(key, null);
                });
              }
            },
            reduce: '_count'
        end

        def name
          id.sub('system:', '')
        end

        # Query the members view and return the Service objects to which this
        # System belongs. The services are cached so subsequent calls to this
        # method do not query the view.
        def services
          unless @services
            rows = database.view(VIEW_NAME, reduce: false, key: [1, name])['rows'] rescue []
            ids = rows.map {|row| row['value'] }
            @services = Service.all.keys(ids).to_a
          end
          @services
        end

        # Return a Hash of unix user ID to an Array of JID's allowed to access
        # that account. For example:
        # {'apache' => ['alice@wonderland.lit'],
        #  'root'   => ['hatter@wonderland.lit]}
        def permissions
          {}.tap do |perms|
            services.each do |service|
              service.accounts.each do |unix_id|
                jids = (perms[unix_id] ||= [])
                jids << service.users
                jids.flatten!
                jids.sort!.uniq!
              end
            end
          end
        end

        def to_result
          to_hash.clone.keep_if {|k, v| KEYS.include?(k) }.tap do |h|
            h['name'] = h.delete('_id').sub('system:', '')
            h['services'] = services.map {|s| {id: s.id, jid: s.jid, name: s.name} }
            h['permissions'] = permissions
          end
        end

        # Send updated permissions to each system that belongs to the service
        # (or belonged to it before the save).
        def self.notify_members(stream, from, members)
          return if members.empty?
          names = members.map {|m| m['name'] }.uniq
          systems = System.find_by_names(names)
          nodes = systems.map do |system|
            Blather::Stanza::Iq::Query.new(:set).tap do |result|
              result.to = Blather::JID.new(system.name, from.domain)
              result.query.content = system.to_result.to_json
              result.query.namespace = 'http://getvines.com/protocol/systems'
            end
          end
          Throttle.new(stream).async_send(nodes)
        end

        def self.find_attributes
          view = attributes.reduce.group
          view.rows.map {|row| row['key'] }
        end

        def self.find_all
          by_name.rows.map do |row|
            {name: row['key']}
          end
        end

        def self.find_by_name(name)
          find("system:#{name.downcase}")
        end

        # Return an Array of Systems with the given names. This method
        # efficiently bulk loads systems and their services much more quickly
        # than loading systems one by one. Note that the systems returned by
        # this method do not have their ohai data loaded because it's expensive.
        def self.find_by_names(names)
          keys = names.map {|name| [1, name.downcase] }
          rows = database.view(VIEW_NAME, reduce: false, keys: keys)['rows'] rescue []
          ids = rows.map {|row| row['value'] }.uniq
          services = Service.all.keys(ids).to_a
          by_id = Hash[services.map {|s| [s.id, s] }]
          by_name = Hash.new do |h, k|
            h[k] = System.new(id: "system:#{k}").tap do |system|
              system.services = []
            end
          end
          rows.each do |row|
            name = row['key'][1]
            service = by_id[row['value']]
            by_name[name].services << service
          end
          by_name.values
        end
      end
    end
  end
end
