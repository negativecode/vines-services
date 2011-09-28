# encoding: UTF-8

module Vines
  module Services
    module Command
      class Stop
        def run(opts)
          raise 'vines-services [--pid FILE] stop' unless opts[:args].size == 0
          daemon = Vines::Daemon.new(:pid => opts[:pid])
          if daemon.running?
            daemon.stop
            puts 'The vines service has been shutdown'
          else
            puts 'The vines service is not running'
          end
        end
      end
    end
  end
end
