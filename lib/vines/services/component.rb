# encoding: UTF-8

module Vines
  module Services
    # The main starting point for the Vines Services component process. Starts
    # the EventMachine processing loop and registers the component with the
    # configured upstream servers.
    class Component
      include Vines::Log

      def initialize(config)
        @config = config
      end

      def start
        log.info('Vines component started')
        at_exit { log.fatal('Vines component stopped') }
        EM.epoll
        EM.kqueue
        EM.run do
          @config.hosts.each {|host| host.start }
        end
      end
    end
  end
end
