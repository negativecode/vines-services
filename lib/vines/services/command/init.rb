# encoding: UTF-8

module Vines
  module Services
    module Command
      class Init
        def run(opts)
          raise 'vines-services init <domain>' unless opts[:args].size == 1
          @domain = opts[:args].first.downcase
          base = File.expand_path(@domain)
          raise "Directory already initialized: #{@domain}" if File.exists?(base)
          raise "Agent gem required: gem install vines-agent" unless agent_gem_installed?

          @db = find_db
          save_user(ask_for_jid, ask_for_password)
          @token = Kit.auth_token

          Dir.mkdir(base)
          %w[server services agent].each do |sub|
            dir = File.expand_path(sub, base)
            Dir.mkdir(dir)
            Dir.chdir(dir) { send("init_#{sub}") }
          end
          puts "Initialized server, agent, and services directories: #{@domain}"
          puts "Login at http://localhost:5280/"
        end

        private

        def init_server
          `vines init #{@domain}`
          FileUtils.mv(Dir.glob("#{@domain}/*"), '.')
          FileUtils.remove_dir(@domain)
          FileUtils.remove_dir('data/users')
          web = File.expand_path("../../../../../web", __FILE__)
          FileUtils.cp_r(Dir.glob("#{web}/*"), 'web')
          update_server_config('conf/config.rb')
          `vines start -d`
          puts "Started vines server: vines start -d"
        end

        def init_agent
          `vines-agent init #{@domain}`
          FileUtils.mv(Dir.glob("#{@domain}/*"), '.')
          FileUtils.remove_dir(@domain)
          FileUtils.cp("../server/conf/certs/#{@domain}.crt", 'conf/certs')
          require File.expand_path('conf/config.rb')
          token = Vines::Agent::Config.instance.domain.password
          save_user(Vines::JID.new(fqdn, @domain), token, true)
          `vines-agent start -d`
          puts "Started vines agent: vines-agent start -d"
        end

        def init_services
          %w[log pid data data/index data/upload].each {|sub| Dir.mkdir(sub) }
          %w[data data/index data/upload].each {|dir| File.chmod(0700, dir) }
          FileUtils.cp_r(File.expand_path("../../../../../conf", __FILE__), '.')
          File.chmod(0600, 'conf/config.rb')
          update_services_config('conf/config.rb')
          `vines-services start -d`
          puts "Started vines services component: vines-services start -d"
        end

        def agent_gem_installed?
          require 'vines/agent'
        rescue LoadError
          false
        end

        def find_db
          host, port = 'localhost', 5984
          db = @domain.downcase.gsub('.', '_')
          until create_db(host, port, db)
            puts "CouchDB connection failed"
            $stdout.write('CouchDB Host: ')
            host = $stdin.gets.chomp
            $stdout.write('CouchDB Port: ')
            port = $stdin.gets.chomp
          end
          {host: host, port: port, name: db}
        end

        def create_db(host, port, db)
          url = "http://#{host}:#{port}/#{db}"
          begin
            RestClient.head(url)
          rescue RestClient::ResourceNotFound
            RestClient.put(url, nil)
          end
          true
        rescue
          false
        end

        def save_user(jid, password, system=false)
          server = CouchRest::Server.new("http://#{@db[:host]}:#{@db[:port]}")
          CouchRest::Model::Base.database = server.database(@db[:name])
          Fiber.new do
            Vines::Services::CouchModels::User.new.tap do |user|
              user.id = "user:#{jid}"
              user.password = password
              user.system = system
              user.admin! unless system
            end.save
          end.resume
          puts "\nCreated user: #{jid}"
        end

        def ask_for_jid
          jid = nil
          until jid
            $stdout.write('JID: ')
            if node = $stdin.gets.chomp.split('@').first
              jid = Vines::JID.new(node, @domain) rescue nil
            end
          end
          jid
        end

        def ask_for_password
          password = nil
          until password
            $stdout.write('Password: ')
            `stty -echo`
            password = $stdin.gets.chomp
            password = nil if password.empty?
            `stty echo`
            puts unless password
          end
          password
        end

        # Return the fully qualified domain name for this machine. This is used
        # to determine the agent's JID.
        def fqdn
          require 'ohai'
          system = Ohai::System.new
          system.require_plugin('os')
          system.require_plugin('hostname')
          system.fqdn.downcase
        end

        def update_services_config(config)
          text = File.read(config)
          File.open(config, 'w') do |f|
            replaced = text
              .gsub('wonderland.lit', @domain.downcase)
              .gsub('secr3t', @token)
              .gsub("host 'localhost'", "host '#{@db[:host]}'")
              .gsub("port 5984", "port #{@db[:port]}")
              .gsub("database 'xmpp'", "database '#{@db[:name]}'")
            f.write(replaced)
          end
        end

        def update_server_config(config)
          replacement = %Q{
            storage 'couchdb' do
              host '#{@db[:host]}'
              port #{@db[:port]}
              database '#{@db[:name]}'
              tls false
              username ''
              password ''
            end
            components 'vines' => '#{@token}'
          }
          text = File.read(config)
          File.open(config, 'w') do |f|
            replaced = text
              .gsub('Vines::Config.configure do', "require 'vines/services/roster'\n\nVines::Config.configure do")
              .gsub(/\s{4}storage 'fs' do.*\s{4}end/m, replacement)
            f.write(replaced)
          end
        end
      end
    end
  end
end
