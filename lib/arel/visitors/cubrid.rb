module Arel # :nodoc: all
  module Visitors
    class Cubrid < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_Bin(o, collector)
        collector << 'BINARY '
        visit o.expr, collector
      end

      def visit_Arel_Nodes_UnqualifiedColumn(o, collector)
        visit o.expr, collector
      end

      def visit_Arel_Nodes_SelectCore(o, collector)
        o.froms ||= Arel.sql('DB_ROOT')
        super
      end

      def visit_Arel_Nodes_Concat(o, collector)
        collector << ' CONCAT('
        visit o.left, collector
        collector << ', '
        visit o.right, collector
        collector << ') '
        collector
      end

      def visit_Arel_Nodes_IsNotDistinctFrom(o, collector)
        collector = visit o.left, collector
        collector << ' <=> '
        visit o.right, collector
      end

      def visit_Arel_Nodes_IsDistinctFrom(o, collector)
        collector << 'NOT '
        visit_Arel_Nodes_IsNotDistinctFrom o, collector
      end

      def visit_Arel_Nodes_Regexp(o, collector)
        infix_value o, collector, ' REGEXP '
      end

      def visit_Arel_Nodes_NotRegexp(o, collector)
        infix_value o, collector, ' NOT REGEXP '
      end

      # no-op
      def visit_Arel_Nodes_NullsFirst(o, collector)
        visit o.expr, collector
      end

      # In the simple case, Cubrid allows us to place JOINs directly into the UPDATE
      # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
      # these, we must use a subquery.
      def prepare_update_statement(o)
        if o.offset # || has_group_by_and_having?(o) ||
          has_join_sources?(o) && has_limit_or_offset_or_orders?(o)
          super
        else
          o
        end
      end
      alias prepare_delete_statement prepare_update_statement
    end
  end
end
