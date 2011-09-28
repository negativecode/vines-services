# encoding: UTF-8

module Vines
  module Services
    module Command
      class Init
        def run(opts)
          raise 'vines-services init [domain]' unless opts[:args].size == 1
          @domain = opts[:args].first.dup
          dir = File.expand_path(@domain)
          @component_password = Kit.generate_password
          create_directories
          initialize_server
          initialize_component
          initialize_agent
          puts "Initialized service, agent, and server directories: #{@domain}"
        end

        private

        def initialize_server
          Dir.chdir(File.join(@domain, "server"))
          `vines init #{@domain}`
          configure_database
          FileUtils.mv Dir.glob("#{@domain}/*"), "./"
          FileUtils.remove_dir(@domain)
          `vines start -d`
          FileUtils.cp_r(File.expand_path("../../../../../web/index.html", __FILE__), File.join("web", "index.html"))
          FileUtils.cp_r(File.expand_path("../../../../../web/javascripts", __FILE__), File.join("web", "javascripts"))
          FileUtils.cp_r(File.expand_path("../../../../../web/stylesheets", __FILE__), File.join("web", "stylesheets"))
          FileUtils.cp_r(File.expand_path("../../../../../web/images", __FILE__), File.join("web", "images"))
          FileUtils.cp_r(File.expand_path("../../../../../web/coffeescripts", __FILE__), File.join("web", "coffeescripts"))
        end

        def initialize_agent
          Dir.chdir("../agent/")
          `vines-agent init #{@domain}`
          FileUtils.cp("../server/conf/certs/#{@domain}.crt", File.join("#{@domain}", "conf", "certs"))
          agent_password = Kit.generate_password
          jid = Vines::JID.new(fqdn, @domain).bare
          id = "user:#{jid}"
          Fiber.new do
            user = Vines::Services::CouchModels::User.new(id: id)
            user.name = jid
            user.system = true
            user.password = agent_password
            if user.valid?
              user.save
              log.debug("Saving user: #{user}")
            end
          end.resume
          update_agent_config(File.join("#{@domain}", "conf", "config.rb"), agent_password)
          FileUtils.mv Dir.glob("#{@domain}/*"), "./"
          FileUtils.remove_dir(@domain)
          `vines-agent start -d`
        end

        # Coordinate all the configuration required for the service
        def initialize_component
          Dir.chdir("../services/")
          %w[conf].each do |sub|
            FileUtils.cp_r(File.expand_path("../../../../../#{sub}", __FILE__), File.join("."))
          end
          log, pid = %w[log pid data data/index].map do |sub|
            File.join(sub).tap {|subdir| Dir.mkdir(subdir) }
          end
          update_config(File.join("conf", "config.rb"))
          `vines-services start -d`
        end

        #create all the directories for the server, agent, and service
        def create_directories
          Dir.mkdir(@domain)
          %w[server services agent].each do |sub|
            Dir.mkdir(File.join(@domain, sub))
          end
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

        # This will attempt to create a new couch database. If one exists
        # by the name generated, it will not be deleted. This will loop until
        # it gets a valid couch db address and port
        def configure_database
          server, port = "127.0.0.1", 5984
          db_name = @domain.gsub(".", "_").downcase()
          until create_db(server, port, db_name)
            puts "Unable to connect."
            $stdout.write('CouchDB Server: ')
            server = $stdin.gets.chomp
            $stdout.write('CouchDB Port: ')
            port = $stdin.gets.chomp
          end
          @couch_server = server
          @couch_port = port
          @couch_db = db_name
          update_config(File.join(@domain, "conf", "config.rb"))
          @storage = Vines::Services::Storage::CouchDB.new do
            host server
            port port
            database db_name
            index_dir '.'
          end
          create_user
        end

        #Create a new vines user object in the couch database
        def create_user
          jid, password = nil, nil
          until jid
            $stdout.write('JID: ')
            if node = $stdin.gets.chomp.split('@').first
              jid = Vines::JID.new(node, @domain) rescue nil
            end
          end

          until password
            $stdout.write('Password: ')
            `stty -echo`
            password = $stdin.gets.chomp
            password = nil if password.empty?
            `stty echo`
          end
          puts "\nCreated #{jid}"

          id = "user:#{jid}"
          Fiber.new do
            user = Vines::Services::CouchModels::User.new(id: id)
            user.name = jid
            user.password = password
            if user.valid?
              user.save
              log.debug("\nSaving user: #{user}")
            end
          end.resume
        end

        # Set the agents password to the one we generated in this initialization
        def update_agent_config(config, password)
          text = File.read(config)
          File.open(config, 'w') do |f|
            f.write(text.gsub(/password.*/, "password '#{password}'"))
          end
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

        # Change the config file to contain the values we generated or validated.
        def update_config(config)
# FIXME vines.local
          orig_config = """
  host 'vines.local' do
    cross_domain_messages false
    private_storage false
    storage 'fs' do
      dir 'data/users'
    end
    # components 'tea'  => 'secr3t',
    #            'cake' => 'passw0rd'
  end"""
          new_config = """
  host '#{@domain}' do
    cross_domain_messages false
    private_storage true
    storage 'couchdb' do
      host '#{@couch_server}'
      port #{@couch_port}
      database '#{@couch_db}'
      tls false
      username ''
      password ''
    end
    components 'vines'  => '#{@component_password}'
  end"""
          text = File.read(config)
          text = text.gsub(orig_config, new_config)
          text = text.gsub("host 'vines.wonderland.lit'", "host 'vines.#{@domain}'")
          text = text.gsub("secr3t", "#{@component_password}")
          text = text.gsub("host 'localhost'", "host '#{@couch_server}'")
          text = text.gsub("port 5984", "port #{@couch_port}")
          text = text.gsub("database 'xmpp'", "database '#{@couch_db}'")
          File.open(config, 'w') do |f|
            f.write(text)
          end
        end
      end
    end
  end
end


