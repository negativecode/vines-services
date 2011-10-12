# encoding: UTF-8

module Vines
  class Storage
    class CouchDB < Storage
      alias :_services_find_user :find_user

      # Override the user's roster with an auto-populated roster containing
      # the services and systems to which the user has permission to access.
      def find_user(jid)
        user = _services_find_user(jid)
        return unless user
        user.roster = []

        systems, users = find_users.partition {|u| u['system'] }
        systems.map! {|u| u['_id'].sub('user:', '') }
        return user if systems.include?(user.jid.to_s)
        services = find_services(user.jid)

        users.each do |row|
          id = row['_id'].sub('user:', '')
          user.roster << Contact.new(
            :jid => id,
            :name => row['name'],
            :subscription => 'both',
            :groups => ['People']) unless id == jid.to_s
        end

        services.each do |row|
          user.roster << Contact.new(
            :jid => row['jid'],
            :name => row['name'],
            :subscription => 'to',
            :groups => ['Services'])
        end

        find_systems(services).each do |name, groups|
          id = JID.new(name.dup, user.jid.domain).to_s
          user.roster << Contact.new(
            :jid => id,
            :name => name,
            :subscription => 'to',
            :groups => ['Systems', *groups]) if systems.include?(id)
        end

        user.roster << Contact.new(
          :jid => "vines.#{user.jid.domain}",
          :name => 'Vines',
          :subscription => 'to')
        user
      end

      # Return the User documents for all users and systems.
      def find_users
        url = "%s/_design/User/_view/all?reduce=false&include_docs=true" % @url
        http = EM::HttpRequest.new(url).get
        http.errback { yield [] }
        http.callback do
          doc = if http.response_header.status == 200
            rows = JSON.parse(http.response)['rows'] rescue []
            rows.map {|row| row['doc'] }
          end
          yield doc || []
        end
      end
      fiber :find_users

      # Return the Service documents to which this JID has permission to
      # access.
      def find_services(jid)
        url = "%s/_design/Service/_view/by_user?reduce=false&key=%s" % [@url, escape(jid.to_s).to_json]
        http = EM::HttpRequest.new(url).get
        http.errback { yield [] }
        http.callback do
          doc = if http.response_header.status == 200
            rows = JSON.parse(http.response)['rows'] rescue []
            rows.map {|row| row['value'] }
          end
          yield doc || []
        end
      end
      fiber :find_services

      # Find the systems that belong to these services. Return a Hash of
      # system name to list of service names to which it belongs.
      def find_systems(services)
        keys = services.map {|row| [0, row['_id']] }
        url = "%s/_design/System/_view/memberships?reduce=false" % @url
        http = EM::HttpRequest.new(url).post(
          head: {'Content-Type' => 'application/json'},
          body: {keys: keys}.to_json)
        http.errback { yield [] }
        http.callback do
          doc = if http.response_header.status == 200
            rows = JSON.parse(http.response)['rows'] rescue []
            Hash.new {|h, k| h[k] = [] }.tap do |systems|
              rows.each do |row|
                service = services.find {|s| s['_id'] == row['key'][1] }
                systems[row['value']['name']] << service['name']
              end
            end
          end
          yield doc || []
        end
      end
      fiber :find_systems
    end
  end
end
