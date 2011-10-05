# encoding: UTF-8

module Vines
  module Services
    module CouchModels
      class Upload < CouchRest::Model::Base
        extend Storage::CouchDB::ClassMethods

        KEYS = %w[_id name size labels created_at updated_at].freeze

        property :name, String
        property :size, Integer
        property :labels, [String], :default => []

        timestamps!

        validates_uniqueness_of :name
        validates_presence_of :name
        validates_numericality_of :size, only_integer: true, greater_than: -1

        design do
          view :by_name,
            map: %q{
              function(doc) {
                if (doc.type != 'Upload' || !doc.name) return;
                emit(doc.name, doc);
              }
            }

          view :by_label,
            map: %q{
              function(doc) {
                if (doc.type != 'Upload' || !doc.labels) return;
                doc.labels.forEach(function(label) {
                  emit(label, doc);
                });
              }
            },
            reduce: '_count'
        end

        def to_result
          to_hash.clone.keep_if {|k, v| KEYS.include?(k) }
            .tap {|h| h['id'] = h.delete('_id') }
        end

        def self.find_labels
          view = by_label.reduce.group
          view.rows.map {|row| {name: row['key'], size: row['value']} }
        end

        def self.find_by_label(label)
          by_label.key(label).map {|doc| doc.to_result }
        end

        def self.find_by_name(name)
          first_from_view('by_name', name)
        end

        def self.find_all
          by_name.map {|doc| doc.to_result }
        end
      end
    end
  end
end
