# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      module ColumnMethods
        extend ActiveSupport::Concern
        included do
          define_column_methods :blob, :clob, :nchar

          alias :char :nchar
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        def new_column_definition(name, type, **options) # :nodoc:
          case type
          when :primary_key
            type = :integer
            options[:limit] ||= 8
            options[:primary_key] = true
          end

          super
        end

        private

        def aliased_types(_name, fallback)
          fallback
        end

        def integer_like_primary_key_type(type, options)
          options[:auto_increment] = true
          type
        end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
