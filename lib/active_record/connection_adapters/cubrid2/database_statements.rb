# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      module DatabaseStatements
        # Returns an ActiveRecord::Result instance.
        def select_all(*param1, **param2) # :nodoc:
          if ExplainRegistry.collect? && prepared_statements
            unprepared_statement { super }
          else
            super
          end
        end

        def query(sql, name = nil) # :nodoc:
          execute(sql, name)
        end

        def query_values(sql, name = nil) # :nodoc:
          res = exec_query(sql, name)
          res&.rows&.map(&:first)
        end

        def query_value(sql, name = nil) # :nodoc:
          _single_value_from_rows(query(sql, name))
        end

        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :begin, :commit, :explain, :select, :set, :show, :release, :savepoint, :rollback, :describe, :desc, :with
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil)
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
          end

          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone
          # @connection.query_options[:database_timezone] = ActiveRecord.default_timezone

          super
        end

        def exec_query(sql, name = 'SQL', binds = [], prepare: false)
          if without_prepared_statement?(binds)
            execute_and_free(sql, name) do |result|
              _build_stmt_result(result)
            end
          else
            exec_stmt_and_free(sql, name, binds, cache_stmt: prepare) do |_, result|
              _build_stmt_result(result)
            end
          end
        end

        def exec_delete(sql, name = nil, binds = [])
          if without_prepared_statement?(binds)
            @lock.synchronize do
              execute_and_free(sql, name) { |stmt| stmt.affected_rows }
            end
          else
            exec_stmt_and_free(sql, name, binds) { |stmt| stmt.affected_rows }
          end
        end
        alias exec_update exec_delete

        private

        def _build_stmt_result(stmt)
          columns = stmt.column_info.map { |col| col['name'] }
          rows = _extract_rows_from_stmt(stmt)
          build_result(columns: columns, rows: rows)
        end

        def _extract_rows_from_stmt(stmt, as_hash: false)
          rows = []
          if as_hash
            while row = stmt.fetch_hash
              rows << row.symbolize_keys
            end
          else
            while row = stmt.fetch
              rows << row
            end
          end
          rows
        end

        def _single_value_from_rows(rows)
          row = rows.fetch
          row && row.first
        end

        def execute_batch(statements, name = nil)
          combine_multi_statements(statements).each do |statement|
            execute(statement, name)
          end
        end

        def default_insert_value(column)
          super unless column.auto_increment?
        end

        def last_inserted_id(_result)
          stmt = query('SELECT LAST_INSERT_ID() as val_')
          row = stmt.fetch
          row[0]&.to_i
        end

        def supports_set_server_option?
          @connection.respond_to?(:set_server_option)
        end

        def exec_stmt_and_free(sql, name, binds, cache_stmt: false)
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
          end

          materialize_transactions

          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

          type_casted_binds = type_casted_binds(binds)

          log(sql, name, binds, type_casted_binds) do
            stmt = if cache_stmt
                     @statements[sql] ||= @connection.prepare(sql)
                   else
                     @connection.prepare(sql)
                   end

            begin
              result = ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                stmt.execute(*type_casted_binds)
              end
            rescue Cubrid2::Error => e
              if cache_stmt
                @statements.delete(sql)
              else
                stmt.close
              end
              raise e
            end

            ret = yield stmt, result
            result.free if result
            stmt.close unless cache_stmt
            ret
          end
        end
      end
    end
  end
end
