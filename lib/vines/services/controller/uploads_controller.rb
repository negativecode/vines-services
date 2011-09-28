# encoding: UTF-8

module Vines
  module Services
    module Controller
      class UploadsController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/files'

        private

        def get
          forbidden! unless current_user.manage_files?
          id, name, label = %w[id name label].map {|a| node.elements.first[a] }

          if id
            send_doc(Upload.find(id))
          elsif name
            send_doc(Upload.find_by_name(name))
          elsif label
            send_result(rows: Upload.find_by_label(label))
          else
            send_result(rows: Upload.find_all)
          end
        end

        # Uploaded files may have their names and labels updated, but not their
        # size. New files are created by uploading them to the UploadsController,
        # not by saving them here.
        def save
          forbidden! unless current_user.manage_files?
          obj = JSON.parse(node.elements.first.content)
          file = Upload.find(obj['id'])

          unless file
            send_error('item-not-found')
            return
          end

          file.name = obj['name']
          file.labels = obj['labels']
          if file.valid?
            file.save
            send_doc(file)
          else
            send_error('not-acceptable')
          end
        end

        def delete
          forbidden! unless current_user.manage_files?
          if file = Upload.find(node.elements.first['id'])
            file.destroy
            send_result
          else
            send_error('item-not-found')
          end
        end
      end
    end
  end
end
