# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      module SchemaStatements # :nodoc:
        # Returns an array of indexes for the given table.
        def indexes(table_name)
          indexes = []
          current_index = nil
          execute_and_free("SHOW KEYS FROM #{quote_table_name(table_name)}", 'SCHEMA') do |result|
            each_hash(result) do |row|
              if current_index != row[:Key_name]
                next if row[:Key_name] == 'PRIMARY' # skip the primary key

                current_index = row[:Key_name]

                cubrid_index_type = row[:Index_type].downcase.to_sym

                # currently only support btree
                # https://www.cubrid.org/manual/en/11.2/sql/query/show.html?highlight=show%20index#show-index
                index_using = cubrid_index_type
                index_type = nil

                indexes << [
                  row[:Table],
                  row[:Key_name],
                  row[:Non_unique].to_i == 0,
                  [],
                  { lengths: {},
                    orders: {},
                    type: index_type,
                    using: index_using,
                    comment: row[:Comment].presence,
                    null: row[:Null] == 'YES',
                    visible: row[:Visible] == 'YES' }
                ]
              end

              if row[:Func]
                expression = row[:Func]
                expression = +"(#{expression})" unless expression.start_with?('(')
                indexes.last[-2] << expression
                indexes.last[-1][:expressions] ||= {}
                indexes.last[-1][:expressions][expression] = expression
                indexes.last[-1][:orders][expression] = :desc if row[:Collation] == 'D'
              else
                indexes.last[-2] << row[:Column_name]
                indexes.last[-1][:lengths][row[:Column_name]] = row[:Sub_part].to_i if row[:Sub_part]
                indexes.last[-1][:orders][row[:Column_name]] = :desc if row[:Collation] == 'D'
              end
            end
          end

          indexes.map do |index|
            options = index.pop

            if expressions = options.delete(:expressions)
              orders = options.delete(:orders)
              lengths = options.delete(:lengths)

              columns = index[-1].map do |name|
                [name.to_sym, expressions[name] || +quote_column_name(name)]
              end.to_h

              index[-1] = add_options_for_index_columns(
                columns, order: orders, length: lengths
              ).values.join(', ')
            end

            IndexDefinition.new(*index, **options)
          end
        end

        def remove_column(table_name, column_name, type = nil, **options)
          remove_foreign_key(table_name, column: column_name) if foreign_key_exists?(table_name, column: column_name)
          super
        end

        def create_table(table_name, options: default_row_format, **)
          super
        end

        def internal_string_options_for_primary_key
          super.tap do |options|
            if !row_format_dynamic_by_default? && charset =~ /^utf8/
              options[:collation] = collation.sub(/\A[^_]+/, 'utf8')
            end
          end
        end

        def update_table_definition(table_name, base)
          Cubrid2::Table.new(table_name, base)
        end

        def create_schema_dumper(options)
          Cubrid2::SchemaDumper.create(self, options)
        end

        # Maps logical Rails types to Cubrid-specific data types.
        def type_to_sql(type, limit: nil,
                        precision: nil, scale: nil,
                        size: limit_to_size(limit, type),
                        unsigned: nil, **)

          case type.to_s
          when 'integer'
            integer_to_sql(limit)
          when 'float', 'real', 'double', 'double precision'
            float_to_sql(limit)
          when 'text', 'string', 'varchar', 'char varing'
            type_with_size_to_sql('string', size)
          when 'char', 'character'
            type_with_size_to_sql('char', size)
          when 'blob', 'binary'
            type_with_size_to_sql('blob', size)
          when 'clob'
            type_with_size_to_sql('clob', size)
          when 'nchar', 'nchar varing'
            raise 'Not supported from cubrid 9.0'
          else
            super
          end
        end

        def table_alias_length
          # https://www.cubrid.org/manual/en/9.1.0/sql/identifier.html#id2
          222
        end

        private

        def row_format_dynamic_by_default?
          false
        end

        def default_row_format
          return if row_format_dynamic_by_default?

          nil
        end

        def schema_creation
          Cubrid2::SchemaCreation.new(self)
        end

        def create_table_definition(*args, **options)
          Cubrid2::TableDefinition.new(self, *args, **options)
        end

        def new_column_from_field(_table_name, field)
          type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
          default = field[:Default]
          default_function = nil

          if type_metadata.type == :datetime # && /\ACURRENT_TIMESTAMP(?:\([0-6]?\))?\z/i.match?(default)
            default_function = default
            default = nil
          end

          Cubrid2::Column.new(
            field[:Field],
            default,
            type_metadata,
            field[:Null] == 'YES',
            default_function,
            collation: field[:Collation],
            comment: field[:Comment].presence,
            extra: field[:Extra]
          )
        end

        def fetch_type_metadata(sql_type, extra = '')
          Cubrid2::TypeMetadata.new(super(sql_type), extra: extra)
        end

        def extract_foreign_key_action(specifier)
          case specifier
          when 'CASCADE' then :cascade
          when 'SET NULL' then :nullify
          when 'RESTRICT' then :restrict
          end
        end

        def add_index_length(quoted_columns, **options)
          lengths = options_for_index_columns(options[:length])
          quoted_columns.each do |name, column|
            column << "(#{lengths[name]})" if lengths[name].present?
          end
        end

        def add_options_for_index_columns(quoted_columns, **options)
          quoted_columns = add_index_length(quoted_columns, **options)
          super
        end

        def data_source_sql(name = nil, type: nil)
          scope = quoted_scope(name, type: type)
          sql = +'SHOW TABLES '
          sql << " LIKE #{scope[:name]}" if scope[:name]
          sql
        end

        def quoted_scope(name = nil, type: nil)
          schema, name = extract_schema_qualified_name(name)
          scope = {}
          scope[:schema] = schema ? quote(schema) : 'database()'
          scope[:name] = quote(name) if name
          scope[:type] = quote(type) if type
          scope
        end

        def extract_schema_qualified_name(string)
          return [] if string.nil? 
          
          q1 = '[`\"\[]'
          q2 = '[`\"\]]'
          schema, name = string.scan(/[^`"\[\].]+|#{q1}[^"]*#{q2}/)
          if name.nil?
            name = schema
            schema = nil
          end
          [schema, name]
        end

        def type_with_size_to_sql(type, _size)
          case type
          when 'string'
            'varchar'
          when 'char'
            'char'
          when 'blob'
            'blob'
          when 'clob'
            'clob'
          end
        end

        def limit_to_size(limit, type)
          case type.to_s
          when 'text', 'blob', 'binary'
            case limit
            when 0..0xff then               'tiny'
            when nil, 0x100..0xffff then    nil
            when 0x10000..0xffffff then     'medium'
            when 0x1000000..0xffffffff then 'long'
            else raise ArgumentError, "No #{type} type has byte size #{limit}"
            end
          end
        end

        def integer_to_sql(limit)
          case limit
          when 1 then 'smallint'
          when 2 then 'smallint'
          when 3 then 'int'
          when nil, 4 then 'int'
          when 5..8 then 'bigint'
          when 9..16 then 'decimal'
          else raise ArgumentError, "No integer type has byte size #{limit}. Use a decimal with scale 0 instead."
          end
        end

        def float_to_sql(limit)
          case limit
          when nil, 1..4 then 'float'
          when 5..8 then 'double'
          else raise ArgumentError, "No float type has byte size #{limit}. Use a decimal with scale 0 instead."
          end
        end
      end
    end
  end
end
