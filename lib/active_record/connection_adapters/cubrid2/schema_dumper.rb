# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        private

        def prepare_column_options(column)
          spec = super
          spec[:auto_increment] = 'true' if column.auto_increment?
          spec
        end

        def column_spec_for_primary_key(column)
          spec = super
          spec.delete(:auto_increment) if column.type == :integer && column.auto_increment?
          spec
        end

        def default_primary_key?(column)
          super && column.auto_increment?
        end

        def explicit_primary_key_default?(column)
          column.type == :integer && !column.auto_increment?
        end
      end
    end
  end
end
