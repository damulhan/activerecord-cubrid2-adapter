# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/cubrid2/column'
require 'active_record/connection_adapters/cubrid2/explain_pretty_printer'
require 'active_record/connection_adapters/cubrid2/quoting'
require 'active_record/connection_adapters/cubrid2/schema_creation'
require 'active_record/connection_adapters/cubrid2/schema_definitions'
require 'active_record/connection_adapters/cubrid2/schema_dumper'
require 'active_record/connection_adapters/cubrid2/schema_statements'
require 'active_record/connection_adapters/cubrid2/type_metadata'
require 'active_record/connection_adapters/cubrid2/version'
require 'arel/visitors/cubrid'

module ActiveRecord
  module ConnectionAdapters
    class AbstractCubrid2Adapter < AbstractAdapter
      include Cubrid2::Quoting
      include Cubrid2::SchemaStatements

      ##
      # :singleton-method:
      # By default, the CubridAdapter will consider all columns of type <tt>tinyint(1)</tt>
      # as boolean. If you wish to disable this emulation you can add the following line
      # to your application.rb file:
      #
      #   ActiveRecord::ConnectionAdapters::CubridAdapter.emulate_booleans = false
      class_attribute :emulate_booleans, default: true

      NATIVE_DATABASE_TYPES = {
        primary_key: 'bigint auto_increment PRIMARY KEY',
        string: { name: 'varchar', limit: 255 }, # 1_073_741_823
        text: { name: 'text' },
        integer: { name: 'int', limit: 4 },
        float: { name: 'float', limit: 24 },
        decimal: { name: 'decimal' },
        datetime: { name: 'datetime' },
        timestamp: { name: 'timestamp' },
        time: { name: 'time' },
        date: { name: 'date' },
        binary: { name: 'blob' },
        blob: { name: 'blob' },
        boolean: { name: 'smallint' },
        json: { name: 'json' }
      }

      class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
        private

        def dealloc(stmt)
          stmt.close
        end
      end

      def initialize(connection, logger, _connection_options, config)
        super(connection, logger, config)
      end

      def get_database_version # :nodoc:
        full_version_string = get_full_version
        version_string = version_string(full_version_string)
        Version.new(version_string, full_version_string)
      end

      def supports_bulk_alter?
        true
      end

      def supports_index_sort_order?
        false
      end

      def supports_expression_index?
        false
      end

      def supports_transaction_isolation?
        true
      end

      def supports_explain?
        true
      end

      def supports_indexes_in_create?
        true
      end

      def supports_foreign_keys?
        true
      end

      def supports_views?
        true
      end

      def supports_datetime_with_precision?
        false
      end

      def supports_virtual_columns?
        true
      end

      def supports_optimizer_hints?
        false
      end

      def supports_common_table_expressions?
        database_version >= '10.2'
      end

      def supports_advisory_locks?
        false
      end

      def supports_insert_on_duplicate_skip?
        true
      end

      def supports_insert_on_duplicate_update?
        true
      end

      def supports_rename_column?
        true
      end

      # In cubrid: locking is done automatically
      # See: https://www.cubrid.org/manual/en/11.2/sql/transaction.html#id13
      def get_advisory_lock(_lock_name, _timeout = 0) # :nodoc:
        # query_value("SELECT GET_LOCK(#{quote(lock_name.to_s)}, #{timeout})") == 1
        true
      end

      def release_advisory_lock(_lock_name) # :nodoc:
        # query_value("SELECT RELEASE_LOCK(#{quote(lock_name.to_s)})") == 1
        true
      end

      def native_database_types
        NATIVE_DATABASE_TYPES
      end

      def index_algorithms
        {}
      end

      # HELPER METHODS ===========================================

      # The two drivers have slightly different ways of yielding hashes of results, so
      # this method must be implemented to provide a uniform interface.
      def each_hash(result) # :nodoc:
        raise NotImplementedError
      end

      # Must return the Cubrid error number from the exception, if the exception has an
      # error number.
      def error_number(exception) # :nodoc:
        raise NotImplementedError
      end

      # REFERENTIAL INTEGRITY ====================================

      # def disable_referential_integrity # :nodoc:
      #   old = query_value('SELECT @@FOREIGN_KEY_CHECKS')

      #   begin
      #     update('SET FOREIGN_KEY_CHECKS = 0')
      #     yield
      #   ensure
      #     update("SET FOREIGN_KEY_CHECKS = #{old}")
      #   end
      # end

      # CONNECTION MANAGEMENT ====================================

      # def clear_cache! # :nodoc:
      #   reload_type_map
      #   super
      # end

      #--
      # DATABASE STATEMENTS ======================================
      #++

      def explain(arel, binds = [])
        sql     = "EXPLAIN #{to_sql(arel, binds)}"
        start   = Concurrent.monotonic_time
        result  = exec_query(sql, 'EXPLAIN', binds)
        elapsed = Concurrent.monotonic_time - start

        Cubrid2::ExplainPrettyPrinter.new.pp(result, elapsed)
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        materialize_transactions

        stmt = nil

        log(sql, name) do
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
            stmt = @connection.query(sql)
          end
        end

        stmt
      end

      # CubridAdapter doesn't have to free a result after using it, but we use this method
      # to write stuff in an abstract way without concerning ourselves about whether it
      # needs to be explicitly freed or not.
      def execute_and_free(sql, name = nil) # :nodoc:
        yield execute(sql, name)
      end

      def begin_db_transaction
        # NOTE: no begin statement in cubrid
        # execute "BEGIN"
      end

      def begin_isolated_db_transaction(isolation)
        execute "SET TRANSACTION ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}"
        begin_db_transaction
      end

      def commit_db_transaction # :nodoc:
        execute 'COMMIT'
      end

      def exec_rollback_db_transaction # :nodoc:
        execute 'ROLLBACK'
      end

      def empty_insert_statement_value(_primary_key = nil)
        'VALUES ()'
      end

      # SCHEMA STATEMENTS ========================================

      # Drops the database: not supported now
      def recreate_database(_name, _options = {})
        raise 'In Cubrid create/drop database not supported'
      end

      # Create a new Cubrid database: not supported now
      def create_database(_name, _options = {})
        raise 'In Cubrid create/drop database not supported'
      end

      # Drops a Cubrid database: not supported now
      def drop_database(_name) # :nodoc:
        raise 'In Cubrid create/drop database not supported'
      end

      def current_database
        query_value('SELECT database()', 'SCHEMA')
      end

      # Returns the database character set.
      def charset
        # check character set:
        # See: https://www.cubrid.com/qna/3802763
        @charset ||= query_value("select charset('ABC')", 'SCHEMA')
      end

      # Returns the database collation strategy.
      def collation
        # check collation set:
        # See: https://www.cubrid.com/qna/3802763
        @collation ||= query_value("select collation('ABC')", 'SCHEMA')
      end

      def table_comment(table_name) # :nodoc:
        raise 'table comment not supported' unless supports_comments?

        query_value(<<~SQL, 'SCHEMA').presence
          SELECT comment
          FROM db_class
          WHERE owner_name = 'PUBLIC'
            AND class_type = 'CLASS'
            AND is_system_class = 'NO'
            AND class_name = #{quote_table_name(table_name)}
        SQL
      end

      def change_table_comment(table_name, comment_or_changes) # :nodoc:
        comment = extract_new_comment_value(comment_or_changes)
        comment = '' if comment.nil?
        execute("ALTER TABLE #{quote_table_name(table_name)} COMMENT=#{quote(comment)}")
      end

      # Renames a table.
      #
      # Example:
      #   rename_table('octopuses', 'octopi')
      def rename_table(table_name, new_name)
        execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
        rename_table_indexes(table_name, new_name)
      end

      # Drops a table from the database.
      #
      # [<tt>:force</tt>]
      #   Set to +:cascade+ to drop dependent objects as well.
      #   Defaults to false.
      # [<tt>:if_exists</tt>]
      #   Set to +true+ to only drop the table if it exists.
      #   Defaults to false.
      # [<tt>:temporary</tt>]
      #   Set to +true+ to drop temporary table.
      #   Defaults to false.
      #
      # Although this command ignores most +options+ and the block if one is given,
      # it can be helpful to provide these in a migration's +change+ method so it can be reverted.
      # In that case, +options+ and the block will be used by create_table.
      def drop_table(table_name, options = {})
        if_exists = (options[:if_exists] ? 'IF EXISTS' : '')
        cascade = (options[:force] == :cascade ? 'CASCADE CONSTRAINTS' : '')
        execute "DROP TABLE #{if_exists} #{quote_table_name(table_name)} #{cascade}"
      end

      def rename_index(table_name, old_name, new_name)
        if supports_rename_index?
          validate_index_length!(table_name, new_name)

          # NOTE: Renaming table index SQL would not work.
          # See: https://www.cubrid.org/manual/ko/10.2/sql/schema/index_stmt.html#alter-index
          #      https://www.cubrid.com/index.php?mid=qna&document_srl=3802148
          _query = "ALTER INDEX #{quote_table_name(old_name)} ON #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
          puts "Warning: renaming index not work as manual. Ignoring: #{_query}"
          #execute _query
        else
          super
        end
      end

      def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
        default = extract_new_default_value(default_or_changes)
        change_column table_name, column_name, nil, default: default
      end

      def change_column_null(table_name, column_name, null, default = nil) # :nodoc:
        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end

        change_column table_name, column_name, nil, null: null
      end

      def change_column_comment(table_name, column_name, comment_or_changes) # :nodoc:
        comment = extract_new_comment_value(comment_or_changes)
        change_column table_name, column_name, nil, comment: comment
      end

      def change_column(table_name, column_name, type, options = {}) # :nodoc:
        execute("ALTER TABLE #{quote_table_name(table_name)} #{change_column_for_alter(table_name, column_name, type,
                                                                                       **options)}")
      end

      def rename_column(table_name, column_name, new_column_name) # :nodoc:
        execute("ALTER TABLE #{quote_table_name(table_name)} #{rename_column_for_alter(table_name, column_name,
                                                                                       new_column_name)}")
        rename_column_indexes(table_name, column_name, new_column_name)
      end

      def add_index(table_name, column_name, options = {}) # :nodoc:
        index, algorithm, if_not_exists = add_index_options(table_name, column_name, **options)

        return if if_not_exists && index_exists?(table_name, column_name, name: index.name)

        create_index = CreateIndexDefinition.new(index, algorithm)
        execute schema_creation.accept(create_index)
      end

      def add_sql_comment!(sql, comment) # :nodoc:
        return sql unless supports_comments?

        sql << " COMMENT #{quote(comment)}" if comment.present?
        sql
      end

      def foreign_keys(table_name)
        raise ArgumentError unless table_name.present?

        # In Cubrid, we cannot know referencing table that foreign key indicates from the system catalog.
        # See: https://www.cubrid.com/qna/3822484
        # So we use the raw sql generated by 'SHOW CREATE TABLE ...'

        tableinfo = create_table_info(table_name)
        lines = tableinfo.gsub('CONSTRAINT', "\nCONSTRAINT").split('CONSTRAINT')

        fkeys = []
        lines.each do |line|
          fk_matches = line.match(/(.*) FOREIGN KEY (.*)/)
          next if fk_matches.nil?

          name = _strip_key_str(fk_matches[1])
          detail_match = fk_matches[2].match(/(.*) REFERENCES (.*) ON DELETE (.*) ON UPDATE (.*)\s*/)

          column = _strip_key_str(detail_match[1])
          to_table_match = detail_match[2]&.match(/(.*)\s+\((.*)\)/)

          to_table = _strip_key_str(to_table_match[1])
          primary_key = _strip_key_str(to_table_match[2])

          options = {
            name: name,
            column: column,
            primary_key: primary_key
          }

          options[:on_update] = extract_foreign_key_action(_strip_left_str(detail_match[3]))
          options[:on_delete] = extract_foreign_key_action(_strip_left_str(detail_match[4]))

          fkeys << ForeignKeyDefinition.new(table_name, to_table, options)
        end

        fkeys
      end

      def _strip_key_str(str)
        str.gsub(/[\[\]]/, '')
           .gsub(/[()]/, '')
           .gsub(/^\s+/, '').gsub(/\s+$/, '')
      end

      def _strip_left_str(str)
        str.gsub(/([;,)].*)$/, '')
      end

      def table_options(table_name) # :nodoc:
        table_options = {}

        tableinfo = create_table_info(table_name)

        # strip create_definitions and partition_options
        # Be aware that `create_table_info` might not include any table options due to `NO_TABLE_OPTIONS` sql mode.
        raw_table_options = tableinfo.sub(/\A.*\n\) ?/m, '').sub(%r{\n/\*!.*\*/\n\z}m, '').strip

        table_options[:options] = raw_table_options unless raw_table_options.blank?

        # strip COMMENT
        table_options[:comment] = table_comment(table_name) if raw_table_options.sub!(/ COMMENT='.+'/, '')

        table_options
      end

      # SHOW VARIABLES LIKE 'name'
      def show_variable(_name)
        raise 'Not supported'
      end

      def primary_keys(table_name) # :nodoc:
        raise ArgumentError unless table_name.present?

        prikeys = []
        column_definitions(table_name).each do |col|
          prikeys << col[:Field] if col[:Key] == 'PRI'
        end
        prikeys
      end

      def default_uniqueness_comparison(attribute, value, klass) # :nodoc:
        column = column_for_attribute(attribute)

        if column.collation && !column.case_sensitive? && !value.nil?
          ActiveSupport::Deprecation.warn(<<~MSG.squish)
            Uniqueness validator will no longer enforce case sensitive comparison in Rails 6.1.
            To continue case sensitive comparison on the :#{attribute.name} attribute in #{klass} model,
            pass `case_sensitive: true` option explicitly to the uniqueness validator.
          MSG
          attribute.eq(Arel::Nodes::Bin.new(value))
        else
          super
        end
      end

      def case_sensitive_comparison(attribute, value) # :nodoc:
        column = column_for_attribute(attribute)

        if column.collation && !column.case_sensitive?
          attribute.eq(Arel::Nodes::Bin.new(value))
        else
          super
        end
      end

      def can_perform_case_insensitive_comparison_for?(column)
        column.case_sensitive?
      end
      private :can_perform_case_insensitive_comparison_for?

      def columns_for_distinct(columns, orders) # :nodoc:
        order_columns = orders.reject(&:blank?).map do |s|
          # Convert Arel node to string
          s = visitor.compile(s) unless s.is_a?(String)
          # Remove any ASC/DESC modifiers
          s.gsub(/\s+(?:ASC|DESC)\b/i, '')
        end.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

        (order_columns << super).join(', ')
      end

      # def strict_mode?
      #   self.class.type_cast_config_to_boolean(@config.fetch(:strict, true))
      # end

      def default_index_type?(index) # :nodoc:
        index.using == :btree || super
      end

      def build_insert_sql(insert) # :nodoc:
        sql = +"INSERT #{insert.into} #{insert.values_list}"

        if insert.skip_duplicates?
          no_op_column = quote_column_name(insert.keys.first)
          sql << " ON DUPLICATE KEY UPDATE #{no_op_column}=#{no_op_column}"
        elsif insert.update_duplicates?
          sql << ' ON DUPLICATE KEY UPDATE '
          sql << insert.updatable_columns.map { |column| "#{column}=VALUES(#{column})" }.join(',')
        end

        sql
      end

      def check_version # :nodoc:
        return unless database_version < '9.0'

        raise "Your version of Cubrid (#{database_version}) is too old. Active Record supports Cubrid >= 9.0."
      end

      private

      def initialize_type_map(m = type_map)
        super

        register_class_with_limit m, /char/i, CubridString

        m.register_type(/blob/i,       Type::Binary.new(limit: 2**30 - 1))
        m.register_type(/clob/i,       Type::Binary.new(limit: 2**30 - 1))
        m.register_type(/^float/i,     Type::Float.new(limit: 24))
        m.register_type(/^double/i,    Type::Float.new(limit: 53))

        register_integer_type m, /^bigint/i,    limit: 8
        register_integer_type m, /^int/i,       limit: 4
        register_integer_type m, /^smallint/i,  limit: 2

        m.register_type(/^smallint\(1\)/i, Type::Boolean.new) if emulate_booleans
        m.alias_type(/year/i,          'integer')
        m.alias_type(/bit/i,           'binary')

        m.register_type(/enum/i) do |sql_type|
          limit = sql_type[/^enum\s*\((.+)\)/i, 1]
                  .split(',').map { |enum| enum.strip.length - 2 }.max
          CubridString.new(limit: limit)
          # String.new(limit: limit)
        end

        m.register_type(/^set/i) do |sql_type|
          limit = sql_type[/^set\s*\((.+)\)/i, 1]
                  .split(',').map { |set| set.strip.length - 1 }.sum - 1
          CubridString.new(limit: limit)
          # String.new(limit: limit)
        end
      end

      def register_integer_type(mapping, key, **options)
        mapping.register_type(key) do |_sql_type|
          # if /\bunsigned\b/.match?(sql_type)
          #   Type::UnsignedInteger.new(**options)
          # else
          Type::Integer.new(**options)
          # end
        end
      end

      def extract_precision(sql_type)
        if /\A(?:date)?time(?:stamp)?\b/.match?(sql_type)
          super || 0
        else
          super
        end
      end

      # See https://www.cubrid.com/tutorial/3793681
      # ER_FILSORT_ABORT        = 1028
      ER_DUP_ENTRY            = 212
      ER_NOT_NULL_VIOLATION   = 631
      # ER_NO_REFERENCED_ROW    = 1216
      # ER_ROW_IS_REFERENCED    = 1217
      ER_DO_NOT_HAVE_DEFAULT  = 1364
      # ER_ROW_IS_REFERENCED_2  = 1451
      # ER_NO_REFERENCED_ROW_2  = 1452
      ER_DATA_TOO_LONG        = 781, 531
      ER_OUT_OF_RANGE         = 935
      ER_LOCK_DEADLOCK        = [72..76]
      ER_CANNOT_ADD_FOREIGN   = [920, 921, 922, 927]
      ER_CANNOT_CREATE_TABLE  = 65,
                                # ER_LOCK_WAIT_TIMEOUT    = 1205
                                ER_QUERY_INTERRUPTED = 790
      # ER_QUERY_TIMEOUT        = 3024
      ER_FK_INCOMPATIBLE_COLUMNS = [918, 923]

      def translate_exception(exception, message:, sql:, binds:)
        case error_number(exception)
        when ER_DUP_ENTRY
          RecordNotUnique.new(message, sql: sql, binds: binds)
          # when ER_NO_REFERENCED_ROW, ER_ROW_IS_REFERENCED, ER_ROW_IS_REFERENCED_2, ER_NO_REFERENCED_ROW_2
          # InvalidForeignKey.new(message, sql: sql, binds: binds)
        when ER_CANNOT_ADD_FOREIGN, ER_FK_INCOMPATIBLE_COLUMNS
          mismatched_foreign_key(message, sql: sql, binds: binds)
        when ER_CANNOT_CREATE_TABLE
          super
        when ER_DATA_TOO_LONG
          ValueTooLong.new(message, sql: sql, binds: binds)
        when ER_OUT_OF_RANGE
          RangeError.new(message, sql: sql, binds: binds)
        when ER_NOT_NULL_VIOLATION, ER_DO_NOT_HAVE_DEFAULT
          NotNullViolation.new(message, sql: sql, binds: binds)
        when ER_LOCK_DEADLOCK
          Deadlocked.new(message, sql: sql, binds: binds)
        # when ER_LOCK_WAIT_TIMEOUT
        #   LockWaitTimeout.new(message, sql: sql, binds: binds)
        # when ER_QUERY_TIMEOUT #, ER_FILSORT_ABORT
        #   StatementTimeout.new(message, sql: sql, binds: binds)
        when ER_QUERY_INTERRUPTED
          QueryCanceled.new(message, sql: sql, binds: binds)
        else
          super
        end
      end

      def change_column_for_alter(table_name, column_name, type, options = {})
        column = column_for(table_name, column_name)
        type ||= column.sql_type

        options[:default] = column.default unless options.key?(:default)
        options[:null] = column.null unless options.key?(:null)
        options[:comment] = column.comment unless options.key?(:comment)

        td = create_table_definition(table_name)
        cd = td.new_column_definition(column.name, type, **options)
        schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))
      end

      def rename_column_for_alter(table_name, column_name, new_column_name)
        return rename_column_sql(table_name, column_name, new_column_name) if supports_rename_column?

        column  = column_for(table_name, column_name)
        options = {
          default: column.default,
          null: column.null,
          auto_increment: column.auto_increment?,
          comment: column.comment
        }

        current_type = exec_query("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE #{quote(column_name)}",
                                  'SCHEMA').first['Type']
        td = create_table_definition(table_name)
        cd = td.new_column_definition(new_column_name, current_type, **options)
        schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))
      end

      def add_index_for_alter(table_name, column_name, **options)
        index, algorithm, = add_index_options(table_name, column_name, **options)
        algorithm = ", #{algorithm}" if algorithm

        "ADD #{schema_creation.accept(index)}#{algorithm}"
      end

      def remove_index_for_alter(table_name, column_name = nil, **options)
        index_name = index_name_for_remove(table_name, column_name, options)
        "DROP INDEX #{quote_column_name(index_name)}"
      end

      def supports_rename_index?
        # https://www.cubrid.org/manual/en/10.0/sql/schema/index_stmt.html#alter-index
        database_version >= '10.0'
      end

      def configure_connection; end

      def column_definitions(table_name) # :nodoc:
        execute_and_free("EXPLAIN #{quote_table_name(table_name)}", 'SCHEMA') do |result|
          each_hash(result)
        end
      end

      def create_table_info(table_name) # :nodoc:
        res = exec_query("SHOW CREATE TABLE #{quote_table_name(table_name)}", 'SCHEMA')
        res.first['CREATE TABLE']
      end

      def arel_visitor
        Arel::Visitors::Cubrid.new(self)
      end

      def build_statement_pool
        StatementPool.new(self.class.type_cast_config_to_integer(@config[:statement_limit]))
      end

      def mismatched_foreign_key(message, sql:, binds:)
        q1 = '[`"\[]'
        q2 = '[`"\]]'
        match = /
          (?:CREATE|ALTER)\s+TABLE\s*(?:#{q1}?\w+#{q2}?\.)?#{q1}?(?<table>\w+)#{q2}?.+?
          FOREIGN\s+KEY\s*\(#{q1}?(?<foreign_key>\w+)#{q2}?\)\s*
          REFERENCES\s*(#{q1}?(?<target_table>\w+)#{q2}?)\s*\(#{q1}?(?<primary_key>\w+)#{q2}?\)
        /xmi.match(sql)

        options = {
          message: message,
          sql: sql,
          binds: binds
        }

        if match
          options[:table] = match[:table]
          options[:foreign_key] = match[:foreign_key]
          options[:target_table] = match[:target_table]
          options[:primary_key] = match[:primary_key]
          options[:primary_key_column] = column_for(match[:target_table], match[:primary_key])
        end

        MismatchedForeignKey.new(**options)
      end

      def version_string(full_version_string)
        full_version_string.match(/^(?:5\.5\.5-)?(\d+\.\d+\.\d+.\d+)/)[1]
      end

      class CubridString < Type::String # :nodoc:
        def serialize(value)
          case value
          when true then '1'
          when false then '0'
          else super
          end
        end

        private

        def cast_value(value)
          case value
          when true then '1'
          when false then '0'
          else super
          end
        end
      end

      ActiveRecord::Type.register(:string, CubridString, adapter: :cubrid)
    end
  end
end
