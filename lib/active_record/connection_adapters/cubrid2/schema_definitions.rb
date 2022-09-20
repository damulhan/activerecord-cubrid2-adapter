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
          when :virtual
            type = options[:type]
          when :primary_key
            type = :integer
            options[:limit] ||= 8
            options[:primary_key] = true
          when /\Aunsigned_(?<type>.+)\z/
            # unsigned is ignored in cubrid
            type = $~[:type].to_sym
            options[:unsigned] = false
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
