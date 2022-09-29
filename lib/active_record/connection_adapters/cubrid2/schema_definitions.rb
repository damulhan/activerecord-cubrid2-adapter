# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      module ColumnMethods
        extend ActiveSupport::Concern
        included do
          define_column_methods :blob, :clob, :nchar

          alias_method :char, :nchar
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

      class IndexDefinition < ActiveRecord::ConnectionAdapters::IndexDefinition
        attr_reader :null, :visible

        def initialize(table, name, unique = false, columns = [], **options)
          options.tap do |o|
            o[:lengths] ||= {}
            o[:orders] ||= {}
            o[:opclasses] ||= {}
          end

          # get rise to error
          @visible = options.delete(:visible)
          @null = options.delete(:null)

          super(table, name, unique, columns, **options)
        end

        def column_options
          super.tap { |o|
            o[:null] = @null
            o[:visible] = @visible
          }
        end

        private

        def concise_options(options)
          if columns.size == options.size && options.values.uniq.size == 1
            options.values.first
          else
            options
          end
        end
      end
    end
  end
end
