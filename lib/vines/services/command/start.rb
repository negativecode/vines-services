# encoding: UTF-8

module Vines
  module Services
    module Command
      class Start
        def run(opts)
          raise 'vines-services [--pid FILE] start' unless opts[:args].size == 0
          require opts[:config]
          component = Vines::Services::Component.new(Config.instance)
          daemonize(opts) if opts[:daemonize]
          component.start
        end

        private

        def daemonize(opts)
          daemon = Vines::Daemon.new(:pid => opts[:pid], :stdout => opts[:log],
            :stderr => opts[:log])
          if daemon.running?
            raise "The vines service is running as process #{daemon.pid}"
          else
            puts "The vines service has started"
            daemon.start
          end
        end
      end
    end
  end
end
