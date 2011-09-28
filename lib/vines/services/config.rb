# encoding: UTF-8

module Vines
  module Services
    # A Config object is passed to the xmpp connections to give them access
    # to server configuration information like component subdomain host names,
    # storage systems, etc. This class provides the DSL methods used in the
    # conf/config.rb file.
    class Config
      LOG_LEVELS = %w[debug info warn error fatal].freeze

      attr_reader :vhosts

      @@instance = nil
      def self.configure(&block)
        @@instance = self.new(&block)
      end

      def self.instance
        @@instance
      end

      def initialize(&block)
        @vhosts = {}
        instance_eval(&block)
        raise "must define at least one virtual host" if @vhosts.empty?
      end

      def host(*names, &block)
        names = names.flatten.map {|name| name.downcase }
        dupes = names.uniq.size != names.size || (@vhosts.keys & names).any?
        raise "one host definition per domain allowed" if dupes
        names.each do |name|
          @vhosts[name] = Host.new(name, &block)
        end
      end

      def log(level)
        const = Logger.const_get(level.to_s.upcase) rescue nil
        unless LOG_LEVELS.include?(level.to_s) && const
          raise "log level must be one of: #{LOG_LEVELS.join(', ')}"
        end
        log = Class.new.extend(Vines::Log).log
        log.progname = 'vines-service'
        log.level = const
        Blather.logger.level = const
      end

      def hosts
        @vhosts.values
      end

      class Host
        attr_reader :name

        def initialize(name, &block)
          @name, @storage, @uploads, @upstream = name, nil, nil, []
          instance_eval(&block)
          raise "storage required for #{@name}" unless @storage
          raise "upstream connection required for #{@name}" if @upstream.empty?
          unless @uploads
            @uploads = File.expand_path('data/upload')
            FileUtils.mkdir_p(@uploads)
          end
        end

        def uploads(dir=nil)
          return @uploads unless dir
          @uploads = File.expand_path(dir)
          begin
            FileUtils.mkdir_p(@uploads)
          rescue
            raise "can't create #{@uploads}"
          end
        end

        def storage(name=nil, &block)
          if name
            raise "one storage mechanism per host allowed" if @storage
            @storage = Storage.from_name(name, &block)
          else
            @storage
          end
        end

        def upstream(host, port, password)
          raise 'host, port, and password required for upstream connections' unless
            host && port && password
          @upstream << {host: host, port: port, password: password}
        end

        def start
          @upstream.each do |info|
            stream = Vines::Services::Connection.new(
              host:     info[:host],
              port:     info[:port],
              password: info[:password],
              vhost:    self)
            stream.start
          end
        end
      end
    end
  end
end
