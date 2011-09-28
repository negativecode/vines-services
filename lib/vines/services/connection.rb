# encoding: UTF-8

module Vines
  module Services
    # Connects the component process to the chat server and provides the protocol
    # used by the web user interface and the agents.
    class Connection
      include Vines::Log

      @@controllers = []
      def self.register(*args, klass)
        @@controllers << [args, klass]
      end

      def initialize(options)
        host, port, password, @vhost = *options.values_at(:host, :port, :password, :vhost)
        @stream = Blather::Client.setup(@vhost.name, password, host, port)
        @throttle = Throttle.new(@stream)
        @queues = {}

        @stream.register_handler(:disconnected) do
          log.info("Stream disconnected, reconnecting . . .")
          EM::Timer.new(10) do
            self.class.new(options).start
          end
          true # prevent EM.stop
        end

        @stream.register_handler(:ready) do
          log.info("Connected #{@stream.jid} component to #{host}:#{port}")
          Fiber.new do
            broadcast_presence
          end.resume
        end

        @stream.register_handler(:iq, '/iq[@type="get"]/ns:query', :ns => 'jabber:iq:version') do |node|
          if node.to == @stream.jid
            iq = Blather::Stanza::Iq::Query.new(:result)
            iq.id, iq.to = node.id, node.from
            iq.query.add_child("<name>Vines Services</name>")
            iq.query.add_child("<version>#{VERSION}</version>")
            @stream.write(iq)
          end
        end

        @@controllers.each do |args, klass|
          @stream.register_handler(*args) do |node|
            jid = node.from.to_s
            start = !@queues.key?(jid)
            queue = (@queues[jid] ||= EM::Queue.new)
            queue.push([node, klass])
            process_node_queue(jid) if start
          end
        end
      end

      def start
        @stream.run
      end

      private

      # Send initial presence from each service JID to its users when the
      # component starts.
      def broadcast_presence
        services = CouchModels::Service.find_all
        users = services.map {|service| service.users }.flatten.uniq
        nodes = users.map {|jid| available(@stream.jid, jid) }
        nodes << services.map do |service|
          service.users.map {|jid| available(service.jid, jid) }
        end
        nodes.flatten!
        @throttle.async_send(nodes)
      end

      def available(from, to)
        Blather::Stanza::Presence::Status.new.tap do |node|
          node.from = from
          node.to = to
        end
      end

      # We must process or deliver stanzas in the order they are received, so
      # we create a node queue for each sending JID and process it in this loop.
      #
      # The process loop continues until the queue is empty for this JID, then
      # the queue is deleted. JID's come and go frequently, without notifying the
      # component, so we must delete their queue as soon as it's empty to avoid
      # maintaining a growing list of queues for JID's we will never see again.
      #
      # Each node is wrapped its own Fiber so it can be paused and resumed
      # during asynchronous IO.
      def process_node_queue(jid)
        if @queues[jid].empty?
          @queues.delete(jid)
        else
          @queues[jid].pop do |pair|
            Fiber.new do
              process_node(*pair)
              process_node_queue(jid)
            end.resume
          end
        end
      end

      # Create a new controller instance to process the node.
      def process_node(node, klass)
        begin
          klass.new(node, @stream, @vhost).process
        rescue Forbidden
          log.warn("Authorization failed for #{node.from}:\n#{node}")
          @stream.write(Blather::StanzaError.new(node, 'forbidden', :auth).to_node)
        rescue Exception => e
          log.error("Error processing node: #{e.message}")
          @stream.write(Blather::StanzaError.new(node, 'internal-server-error', :cancel).to_node)
        end
      end
    end
  end
end
