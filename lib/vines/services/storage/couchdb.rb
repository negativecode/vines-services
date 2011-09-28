# encoding: UTF-8

module Vines
  module Services
    class Storage
      class CouchDB < Storage
        register :couchdb

        module ClassMethods
          # Override CouchRest::Model::Persistence::ClassMethods#build_from_database
          # to instantiate the fully qualified model class name. We store the
          # bare class name in doc['type'] (e.g. Service rather than
          # Vines::Services::CouchModels::Service), so outside query processes
          # don't need to know our class hierarchy.
          def build_from_database(doc = {}, options = {}, &block)
            src = doc[model_type_key]
            base = (src.blank? || src == self.to_s) ? self : "Vines::Services::CouchModels::#{src}".constantize
            base.new(doc, options.merge(:directly_set_attributes => true), &block)
          end

          # CouchRest::Model uses Class#to_s to determine design document names
          # as well as the value of doc['type']. Strip off all module names to
          # get clean design document URLs.
          def to_s
            self.name.split('::').last
          end
        end

        %w[host port database tls username password index_dir].each do |name|
          define_method(name) do |*args|
            if args.first
              @config[name.to_sym] = args.first
            else
              @config[name.to_sym]
            end
          end
        end

        def initialize(&block)
          @config = {}
          instance_eval(&block)
          [:host, :port, :database, :index_dir].each do |key|
            raise "Must provide #{key}" unless @config[key]
          end

          @config[:index_dir] = File.expand_path(@config[:index_dir])
          unless File.directory?(@config[:index_dir]) && File.writable?(@config[:index_dir])
            raise 'Must provide a writable index directory'
          end

          @url = url(@config)
          init_couch_rest

          db = "%s-%s-%s.db" % [host, port, database]
          @index = Indexer[File.join(@config[:index_dir], db)]
        end

        def get(path, &callback)
          http(path, :get, &callback)
        end

        def post(path, body, &callback)
          http(path, :post, body, &callback)
        end

        def delete(path, &callback)
          http(path, :get) do |doc|
            if doc
              http("#{path}?rev=#{doc['_rev']}", :delete, &callback)
            else
              yield
            end
          end
        end

        def save(doc, &callback)
          http('', :post, doc.to_json, &callback)
        end

        def index(system)
          @index << system.ohai
        end

        def query(sql, *params, &callback)
          @index.find(sql, params, &callback)
        end

        def store_file(path)
          file = CouchModels::Upload.find_by_name(File.basename(path))
          unless file
            File.delete(path)
            return
          end

          http = EM::HttpRequest.new("#{@url}/#{file.id}/data?rev=#{file.rev}").put(
            head: {'Content-Type' => 'application/octet-stream'},
            file: path
          )
          http.callback {|chunk| yield }
        end

        def create_views
          # FIXME Use views in CouchRest::Model classes to populate db
          designs = {}

          EM.run do
            http('', :put) do # create db
              designs.each do |name, views|
                get("/_design/#{name}") do |doc|
                  doc ||= {"_id" => "_design/#{name}"}
                  doc['language'] = 'javascript'
                  doc['views'] = views
                  save(doc) { EM.stop }
                end
              end
            end
          end
        end

        private

        def http(path, method, body=nil)
          args = {}.tap do |opts|
            opts[:head] = {'Content-Type' => 'application/json'}
            opts[:body] = body if body
          end

          http = EM::HttpRequest.new("#{@url}#{path}").send(method, args)
          http.errback { yield }
          http.callback do
            doc = if (200...300).include?(http.response_header.status)
              JSON.parse(http.response) rescue nil
            end
            yield doc
          end
        end

        def url(config)
          scheme = config[:tls] ? 'https' : 'http'
          user, password = config.values_at(:username, :password)
          credentials = empty?(user, password) ? '' : "%s:%s@" % [user, password]
          "%s://%s%s:%s/%s" % [scheme, credentials, *config.values_at(:host, :port, :database)]
        end

        def init_couch_rest
          *url, _ = @url.split('/')
          server = CouchRest::Server.new(url.join('/'))
          CouchRest::Model::Base.database = server.database(database)
        end

        def escape(jid)
          URI.escape(jid, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
        end
      end
    end
  end
end
