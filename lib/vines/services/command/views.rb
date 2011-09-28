# encoding: UTF-8

module Vines
  module Services
    module Command
      class Views
        def run(opts)
          raise 'vines-services views <domain>' unless opts[:args].size == 1
          require opts[:config]
          domain = opts[:args].first
          unless host = Config.instance.vhosts[domain]
            raise "#{domain} virtual host not found in conf/config.rb"
          end
          unless host.storage.respond_to?(:create_views)
            raise "CouchDB storage not configured for #{domain} virtual host"
          end
          begin
            host.storage.create_views
          rescue Exception => e
            raise "View creation failed: #{e.message}"
          end
        end
      end
    end
  end
end
