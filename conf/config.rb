# encoding: UTF-8

# This is the Vines Services configuration file. Restart the service with
# 'vines-services restart' after updating this file.

Vines::Services::Config.configure do
  # Set the logging level to debug, info, warn, error, or fatal. The debug
  # level logs all XML sent and received by the server.
  log :info

  host 'vines.wonderland.lit' do
    upstream 'localhost', 5347, 'secr3t'
    uploads 'data/upload'

    storage 'couchdb' do
      host 'localhost'
      port 5984
      database 'xmpp'
      tls false
      username ''
      password ''
      index_dir 'data/index'
    end
  end
end
