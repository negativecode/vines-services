# encoding: UTF-8

module Vines
  module Services
    module VQL
      # Compiles Vines Query Language queries into JavaScript for CouchDB views
      # and SQL for sqlite queries. The output of the compiler is a fully formed
      # query that can be sent directly to the database.
      class Compiler
        Citrus.load(File.expand_path('../vql.citrus', __FILE__))

        # Return the compiled CouchDB map function. Raise an exception on
        # compilation failure. The exception's error message can be shown to
        # the user to debug the syntax.
        def to_js(code)
          raise ArgumentError, 'code required' if code.nil? || code.strip.empty?
          expr = VinesQL.parse(code.strip)
          %Q{
            function(doc) {
              if (doc.type != 'System') return;
              try {
                var match = #{expr.js};
                if (match) {
                  var name = doc['_id'].replace('system:', '');
                  var os = doc.ohai.kernel.os.toLowerCase().replace('gnu/', '');
                  emit(name, os);
                }
              } catch(e) {
                log(e.message);
              }
            }
          }
        end

        # Return the compiled CouchDB map function for all services. Raise an
        # exception on compilation failure. The exception's error message can
        # be shown to the user to debug the syntax.
        def to_full_js(services)
          maps = services.map do |service|
            expr = VinesQL.parse(service.code.strip)
            %Q{
              try {
                var match = #{expr.js};
                if (match) {
                  emit([0, '#{service.id}'], {name: name, os: os});
                  emit([1, name], '#{service.id}');
                }
              } catch(e) {
                log(e.message);
              }
            }
          end

          %Q{
            function(doc) {
              if (doc.type != 'System') return;
              var name = doc['_id'].replace('system:', '');
              var os = doc.ohai.kernel.os.toLowerCase().replace('gnu/', '');
              #{maps.join}
            }
          }
        end

        # Return the compiled sqlite SQL query along with an array of parameter
        # replacement values. Raise an exception on compilation failure. The
        # exception's error message can be shown to the user to debug the syntax.
        def to_sql(code)
          raise ArgumentError, 'code required' if code.nil? || code.strip.empty?
          expr = VinesQL.parse(code.strip)

          keys, values = expr.params.partition.each_with_index {|p, ix| ix % 2 == 0 }
          joins = keys.each_with_index.map do |k, ix|
            "inner join attributes a%s on id=a%s.system_id and a%s.key=?" % [ix, ix, ix]
          end

          where = expr.sql.tap do |sql|
            values.size.times do |ix|
              sql.sub!(/(^|[^\.])value/, "\\1a#{ix}.value")
            end
          end

          sql = %Q{
            select name, os from systems
            #{joins.join("\n")}
            where #{where}
            order by name
          }

          [sql, [keys, values].flatten]
        end
      end
    end
  end
end
