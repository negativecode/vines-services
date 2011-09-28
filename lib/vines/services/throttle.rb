# encoding: UTF-8

module Vines
  module Services
    # Send many outgoing stanzas to the server at a sustained rate that won't
    # cause the server to shutdown the component's stream with a policy_violation
    # error.
    class Throttle
      def initialize(stream, delay=0.1)
        @stream, @delay = stream, delay
      end

      # Send the nodes to the server at a constant rate. The nodes are sent
      # asynchronously, so this method returns immediately.
      def async_send(nodes)
        timer = EM::PeriodicTimer.new(@delay) do
          if node = nodes.shift
            @stream.write(node)
          else
            timer.cancel
          end
        end
      end
    end
  end
end
