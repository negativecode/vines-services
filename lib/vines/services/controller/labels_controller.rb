# encoding: UTF-8

module Vines
  module Services
    module Controller
      class LabelsController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/files/labels'

        def get
          forbidden! unless current_user.manage_files?
          send_result(rows: Upload.find_labels)
        end
      end
    end
  end
end
