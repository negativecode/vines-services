# encoding: UTF-8

module Vines
  module Services
    module CouchModels
      class Fragment < CouchRest::Model::Base
        extend Storage::CouchDB::ClassMethods

        property :xml, String

        design do
          view :by_jid,
            map: %q{
              function(doc) {
                if (doc.type != 'Fragment') return;
                emit(doc['_id'].split(':')[1], null);
              }
            }
        end
      end
    end
  end
end
