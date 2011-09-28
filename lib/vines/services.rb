# encoding: UTF-8

%w[
  couchrest_model
  logger
  bcrypt
  blather/client/client
  cgi
  citrus
  em-http
  fiber
  fileutils
  json
  nokogiri
  sqlite3
  uri

  vines/log
  vines/daemon
  vines/jid
  vines/kit

  vines/services/core_ext/blather
  vines/services/core_ext/couchrest

  vines/services/version
  vines/services/connection
  vines/services/config
  vines/services/component
  vines/services/priority_queue
  vines/services/indexer
  vines/services/throttle

  vines/services/vql/vql
  vines/services/vql/compiler

  vines/services/command/init
  vines/services/command/restart
  vines/services/command/start
  vines/services/command/stop
  vines/services/command/views

  vines/services/storage
  vines/services/storage/couchdb
  vines/services/storage/couchdb/fragment
  vines/services/storage/couchdb/service
  vines/services/storage/couchdb/system
  vines/services/storage/couchdb/upload
  vines/services/storage/couchdb/user
  vines/services/storage/couchdb/vcard

  vines/services/controller/base_controller
  vines/services/controller/attributes_controller
  vines/services/controller/disco_info_controller
  vines/services/controller/uploads_controller
  vines/services/controller/labels_controller
  vines/services/controller/members_controller
  vines/services/controller/messages_controller
  vines/services/controller/probes_controller
  vines/services/controller/services_controller
  vines/services/controller/subscriptions_controller
  vines/services/controller/systems_controller
  vines/services/controller/transfers_controller
  vines/services/controller/users_controller
].each {|f| require f }

module Vines
  module Services
    class Forbidden < StandardError; end
  end
end
