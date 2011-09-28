# encoding: UTF-8

module Vines
  module Services
    module Controller
      class MembersController < BaseController
        register :iq, "/iq[@type='get' or @type='set']/ns:query",
          'ns' => 'http://getvines.com/protocol/services/members'

        private

        def get
          forbidden! unless current_user.manage_services?
          if id = node.elements.first['id']
            rows = Service.find(id).members rescue []
            send_result(rows: rows)
          else
            find_members_by_vql
          end
        end

        # Compile the VQL syntax into a SQL query to find matching member
        # systems. Return a list of members or the parser error so the user
        # can debug their query syntax.
        def find_members_by_vql
          begin
            code = node.elements.first.content
            sql, params = VQL::Compiler.new.to_sql(code)
            query(sql, params)
          rescue Exception => e
            send_result(ok: false, error: e.message)
          end
        end

        def query(sql, params)
          storage.query(sql, params) do |rows|
            members = rows.map {|row| {name: row[0], os: row[1]} }
            send_result(ok: true, rows: members)
          end
        end
      end
    end
  end
end
