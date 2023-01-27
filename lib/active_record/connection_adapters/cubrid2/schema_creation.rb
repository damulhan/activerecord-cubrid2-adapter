# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      class SchemaCreation < ActiveRecord::ConnectionAdapters::SchemaCreation # :nodoc:
        delegate :add_sql_comment!, to: :@conn, private: true

        private

        # def visit_DropForeignKey(name)
        #   "DROP FOREIGN KEY #{name}"
        # end

        def visit_DropCheckConstraint(name)
          "DROP CONSTRAINT #{name}"
        end

        def visit_AddColumnDefinition(o)
          add_column_position!(super, column_options(o.column))
        end

        def visit_ChangeColumnDefinition(o)
          change_column_sql = +"CHANGE #{quote_column_name(o.name)} #{accept(o.column)}"
          add_column_position!(change_column_sql, column_options(o.column))
        end

        def visit_CreateIndexDefinition(o)
          visit_IndexDefinition(o.index, true)
        end

        def visit_IndexDefinition(o, create = false)
          index_type = o.type&.to_s&.upcase || o.unique && 'UNIQUE'

          sql = create ? ['CREATE'] : []
          sql << index_type if index_type
          sql << 'INDEX'
          sql << quote_column_name(o.name)
          # sql << "USING #{o.using}" if o.using
          sql << "ON #{quote_table_name(o.table)}" if create
          sql << "(#{quoted_columns(o)})"

          add_sql_comment!(sql.join(' '), o.comment)
        end

        def add_table_options!(create_sql, options)
          add_sql_comment!(super, options[:comment])
        end

        def add_column_options!(sql, options)
          # In cubrid, default value of timestamp follows system parameter 'return_null_on_function_errors'
          # if return_null_on_function_errors == 'no', timestamp null means error.
          # https://www.cubrid.org/manual/en/10.1/sql/datatype.html#date-time-type
          if /\Atimestamp\b/.match?(options[:column].sql_type) && !options[:primary_key] &&
             !(options[:null] == false || options_include_default?(options))
            sql << ' NULL'
          end

          if (charset = options[:charset])
            sql << " CHARSET #{charset}"
          end

          if (collation = options[:collation])
            sql << " COLLATE #{collation}"
          end

          if (as = options[:as])
            sql << " AS (#{as})"
          end

          add_sql_comment!(super, options[:comment])
        end

        def add_column_position!(sql, options)
          if options[:first]
            sql << ' FIRST'
          elsif options[:after]
            sql << " AFTER #{quote_column_name(options[:after])}"
          end

          sql
        end

        def index_in_create(table_name, column_name, options)
          if ActiveRecord.version.to_s >= '6.1.0'
            # for activerecord >= 6.1
            index_def, algorithm, if_not_exists = @conn.add_index_options(table_name, column_name, **options)

            index_name = index_def.name
            index_columns = index_def.columns.map { |x| quote_column_name(x) }.join(', ')
            index_type = index_def.unique ? 'UNIQUE' : ''
            comment = index_def.comment
          else
            # for activerecord == 6.0
            index_name, index_type, index_columns, _, _, index_using, comment =
                                                        @conn.add_index_options(table_name, column_name, **options)
          end

          add_sql_comment!(+"#{index_type} INDEX #{quote_column_name(index_name)} (#{index_columns})", comment)
        end
      end
    end
  end
end
