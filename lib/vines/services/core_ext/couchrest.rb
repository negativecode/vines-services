# encoding: UTF-8

module CouchRest
  module RestAPI

    # Wrap a blocking IO method in a new method that pushes the original method
    # onto EventMachine's thread pool using EM#defer. The calling Fiber is paused
    # while the thread pool does its work, then resumed when the thread finishes.
    def self.defer(method)
      old = "_deferred_#{method}"
      alias_method old, method
      define_method method do |*args|
        fiber = Fiber.current
        op = proc do
          begin
            method(old).call(*args)
          rescue
            nil
          end
        end
        cb = proc {|result| fiber.resume(result) }
        EM.defer(op, cb)
        Fiber.yield
      end
    end

    # All CouchRest::RestAPI methods ultimately call execute to connect to
    # CouchDB, using blocking IO. Push those blocking calls onto the thread
    # pool so we don't block the reactor thread, but still get to use all
    # of the goodness of CouchRest::Model.
    defer :execute
  end
end
