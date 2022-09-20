# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_cubrid2_adapter'
require 'active_record/connection_adapters/cubrid2/database_statements'
require 'cubrid2'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    ER_DATABASE_CONNECTION_ERROR = -1000

    # Establishes a connection to the database that's used by all Active Record objects.
    def cubrid2_connection(config)
      config = config.symbolize_keys
      config[:flags] ||= 0

      client = Cubrid2::Client.new(config)
      ConnectionAdapters::Cubrid2Adapter.new(client, logger, nil, config)
    rescue Cubrid2::Error => e
      if e.error_number == ER_DATABASE_CONNECTION_ERROR
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
  end

  module ConnectionAdapters
    class Cubrid2Adapter < AbstractCubrid2Adapter
      ADAPTER_NAME = 'Cubrid2'

      include Cubrid2::DatabaseStatements

      def initialize(connection, logger, connection_options, config)
        superclass_config = config.reverse_merge(prepared_statements: false)
        super(connection, logger, connection_options, superclass_config)
        configure_connection
      end

      def adapter_name
        ADAPTER_NAME
      end

      def self.database_exists?(config)
        !!ActiveRecord::Base.cubrid_connection(config)
      rescue ActiveRecord::NoDatabaseError
        false
      end

      def supports_json?
        database_version >= '10.2'
      end

      def supports_comments?
        # https://www.cubrid.org/manual/en/10.0/release_note/r10_0.html#overview
        database_version >= '10.0'
      end

      def supports_comments_in_create?
        true
      end

      def supports_savepoints?
        false
      end

      def supports_lazy_transactions?
        false
      end

      # HELPER METHODS ===========================================
      def each_hash(result) # :nodoc:
        stmt = result.is_a?(Array) ? result.first : result
        if block_given?
          if result && stmt
            while row = stmt.fetch_hash
              yield row.symbolize_keys
            end
          end
        else
          to_enum(:each_hash, stmt)
        end
      end

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end

      #--
      # QUOTING ==================================================
      #++

      def quote_string(string)
        # escaping with backslash is only allowed when 'no_backslash_escapes' == 'yes' in cubrid config, default is yes.
        # See: https://www.cubrid.org/manual/ko/11.2/sql/literal.html#id5
        # "'#{string.gsub("'", "''")}'"
        string
      end

      #--
      # CONNECTION MANAGEMENT ====================================
      #++

      def active?
        @connection.ping
      end

      def reconnect!
        super
        disconnect!
        connect
      end
      alias reset! reconnect!

      # Disconnects from the database if already connected.
      # Otherwise, this method does nothing.
      def disconnect!
        super
        @connection.close
      end

      def discard! # :nodoc:
        super
        @connection.automatic_close = false
        @connection = nil
      end

      def server_version
        @connection.server_version
      end

      def ping
        @connection.ping
      end

      def cubrid_connection
        @connection
      end

      # 오류??
      def auto_commit
        @connection.auto_commit
      end

      def auto_commit=(flag)
        @connection.auto_commit = flag
      end

      private

      def connect
        @connection = Cubrid2::Client.new(@config)
        configure_connection
      end

      def configure_connection
        @connection.query_options[:as] = :array
        super
      end

      def full_version
        schema_cache.database_version.full_version_string
      end

      def get_full_version
        @connection.server_version
      end
    end
  end
end
