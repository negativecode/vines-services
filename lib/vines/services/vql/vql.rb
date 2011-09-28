module Vines
  module Services
    # These modules give semantic meaning to the Vines Query Language Citrus
    # parser. The query language is translated into JavaScript and SQL fragments
    # for use in CouchDB views or sqlite queries. This file must be loaded before
    # vql.citrus.
    module VQL
      module Or
        def js
          "%s || %s" % [lhs.js, rhs.js]
        end
        def sql
          "%s or %s" % [lhs.sql, rhs.sql]
        end
        def params
          [lhs.params, rhs.params].flatten
        end
      end

      module And
        def js
          "%s && %s" % [lhs.js, rhs.js]
        end
        def sql
          "%s and %s" % [lhs.sql, rhs.sql]
        end
        def params
          [lhs.params, rhs.params].flatten
        end
      end

      module Is
        def js
          "(%s === %s)" % [lhs.js, rhs.js]
        end
        def sql
          case rhs
          when Vines::Services::VQL::Null
            "value is null"
          else
            "value=?"
          end
        end
        def params
          case rhs
          when Vines::Services::VQL::Null
            [lhs.sql]
          else
            [lhs.sql, rhs.sql]
          end
        end
      end

      module IsNot
        def js
          "(%s !== %s)" % [lhs.js, rhs.js]
        end
        def sql
          case rhs
          when Vines::Services::VQL::Null
            "value is not null"
          else
            "value <> ?"
          end
        end
        def params
          case rhs
          when Vines::Services::VQL::Null
            [lhs.sql]
          else
            [lhs.sql, rhs.sql]
          end
        end
      end

      module Like
        def js
          "(%s.indexOf(%s) !== -1)" % [lhs.js, rhs.js]
        end
        def sql
          "value like ?"
        end
        def params
          [lhs.sql, "%#{rhs.sql}%"]
        end
      end

      module NotLike
        def js
          "(%s.indexOf(%s) === -1)" % [lhs.js, rhs.js]
        end
        def sql
          "value not like ?"
        end
        def params
          [lhs.sql, "%#{rhs.sql}%"]
        end
      end

      module StartsWith
        def js
          "(%s.lastIndexOf(%s, 0) === 0)" % [lhs.js, rhs.js]
        end
        def sql
          "value like ?"
        end
        def params
          [lhs.sql, "#{rhs.sql}%"]
        end
      end

      module EndsWith
        def js
          "(%s.match(%s + '$'))" % [lhs.js, rhs.js]
        end
        def sql
          "value like ?"
        end
        def params
          [lhs.sql, "%#{rhs.sql}"]
        end
      end

      module LtGt
        def js
          "(%s %s %s)" % [lhs.js, op, rhs.js]
        end
        def sql
          "cast(value as number) %s ?" % op
        end
        def params
          [lhs.sql, rhs.sql]
        end
      end

      module Group
        def js
          "(%s)" % expr.js
        end
        def sql
          "(%s)" % expr.sql
        end
        def params
          expr.params
        end
      end

      module Terminal
        def js
          str.to_s
        end
        def sql
          str.to_s
        end
        def params
          []
        end
      end

      module Member
        include Terminal
        def js
          "doc.ohai.#{str}"
        end
      end

      module SingleQuoted
        include Terminal
        def js
          "'%s'" % str
        end
      end

      module DoubleQuoted
        include Terminal
        def js
          '"%s"' % str
        end
      end

      module Null
        include Terminal
      end
    end
  end
end
