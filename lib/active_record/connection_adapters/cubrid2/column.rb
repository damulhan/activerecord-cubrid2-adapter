# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      class Column < ConnectionAdapters::Column # :nodoc:
        delegate :extra, to: :sql_type_metadata, allow_nil: true

        def unsigned?
          false
        end

        def case_sensitive?
          collation && !collation.end_with?('_ci')
        end

        def auto_increment?
          !respond_to?(:extra) && extra == 'auto_increment'
        end

        def virtual?
          # /\b(?:VIRTUAL|STORED|PERSISTENT)\b/.match?(extra)
          false
        end
      end
    end
  end
end
