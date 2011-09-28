# encoding: UTF-8

module Vines
  module Services
    class Storage
      include Vines::Log

      @@nicks = {}

      # Register a nickname that can be used in the config file to specify this
      # storage implementation.
      def self.register(name)
        @@nicks[name.to_sym] = self
      end

      def self.from_name(name, &block)
        klass = @@nicks[name.to_sym]
        raise "#{name} storage class not found" unless klass
        klass.new(&block)
      end

      private

      # Return true if any of the arguments are nil or empty strings.
      # For example:
      # username, password = 'alice@wonderland.lit', ''
      # empty?(username, password) #=> true
      def empty?(*args)
        args.flatten.any? {|arg| (arg || '').strip.empty? }
      end
    end
  end
end
