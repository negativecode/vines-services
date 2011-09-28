# encoding: UTF-8

module Vines
  module Services
    module CouchModels
      class Vcard < CouchRest::Model::Base
        extend Storage::CouchDB::ClassMethods

        property :card, String
      end
    end
  end
end
