# encoding: UTF-8

module Vines
  module Services
    module Controller
      class AttributesController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/systems/attributes'

        private

        def get
          forbidden! unless current_user.manage_services?
          send_result(rows: System.find_attributes)
        end
      end
    end
  end
end
