# encoding: UTF-8

module Vines
  module Services
    module Command
      class Restart
        def run(opts)
          Stop.new.run(opts)
          Start.new.run(opts)
        end
      end
    end
  end
end
