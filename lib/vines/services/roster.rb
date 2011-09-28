# encoding: UTF-8
module Vines
  class Storage
    class CouchDB < Storage

      ALL_SERVICES = '/_design/Service/_view/by_name'.freeze

      # The existing storage class needs another method for our custom roster queries
      # The default escaping in URLs makes this method necessary
      def get_services
        http = EM::HttpRequest.new("#{@url}#{ALL_SERVICES}").get
        http.errback { yield }
        http.callback do
          doc = if http.response_header.status == 200
            JSON.parse(http.response) rescue nil
          end
          yield doc
        end
      end

      #In order to supply the correct vines roster logic, we need to over ride the default
      #User creation of in the vines server. This method is much more effecient than
      #looking up roster memberships each time the roster is sent.
      def find_user(jid)
        jid = JID.new(jid || '').bare.to_s
        if jid.empty? then yield; return end
        get("user:#{jid}") do |doc|
          user = if doc && doc['type'] == 'User'
            User.new(:jid => jid).tap do |user|
              user.name, user.password = doc.values_at('name', 'password')
              if doc['roster'] != ""
                (doc['roster'] || {}).each_pair do |jid, props|
                  user.roster << Contact.new(
                    :jid => jid,
                    :name => props['name'],
                    :subscription => props['subscription'],
                    :ask => props['ask'],
                    :groups => props['groups'] || [])
                end
              end
              add_user_roster_services(user)
            end
          end
          yield user
        end
      end
      fiber :find_user

      # We will go find each service that contains this user jid in the
      # users of the service document.
      def add_user_roster_services(user)
        self.get_services do |cdoc|
          if cdoc
            rows = cdoc['rows'].map do |row|
              if row['value']['users'].include?(user.jid.to_s)
                jid = JID.new("#{row['value']['jid']}").bare.to_s
                user.roster << Contact.new(
                  :jid => jid,
                  :name => row['value']['name'],
                  :subscription => "both",
                  :ask => "subscribe",
                  :groups => ["Vines"])
              end
            end
          end
        end
      end
    end
  end
end
