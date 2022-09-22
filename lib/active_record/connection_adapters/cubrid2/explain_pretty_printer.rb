# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Cubrid2
      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of an query that resembles Cubrid shell:
        #
        #   Field                 Type                  Null                  Key                   Default               Extra
        # ====================================================================================================================================
        #   'host_year'           'INTEGER'             'NO'                  'PRI'                 NULL                  ''
        #   'event_code'          'INTEGER'             'NO'                  'MUL'                 NULL                  ''
        #   'athlete_code'        'INTEGER'             'NO'                  'MUL'                 NULL                  ''
        #   'stadium_code'        'INTEGER'             'NO'                  ''                    NULL                  ''
        #   'nation_code'         'CHAR(3)'             'YES'                 ''                    NULL                  ''
        #   'medal'               'CHAR(1)'             'YES'                 ''                    NULL                  ''
        #   'game_date'           'DATE'                'YES'                 ''                    NULL                  ''
        #
        # 7 rows selected. (0.010673 sec)
        #
        def pp(result, elapsed)
          widths    = compute_column_widths(result) + 4
          separator = build_separator(widths)

          pp = []

          pp << build_cells(result.columns, widths)
          pp << separator

          result.rows.each do |row|
            pp << build_cells(row, widths)
          end

          pp << build_footer(result.rows.length, elapsed)

          pp.join("\n") + "\n"
        end

        private

        def compute_column_widths(result)
          [].tap do |widths|
            result.columns.each_with_index do |column, i|
              cells_in_column = [column] + result.rows.map { |r| r[i].nil? ? 'NULL' : r[i].to_s }
              widths << cells_in_column.map(&:length).max
            end
          end
        end

        def build_separator(widths)
          '=' * widths
        end

        def build_cells(items, widths)
          cells = []
          items.each_with_index do |item, i|
            item = 'NULL' if item.nil?
            justifier = item.is_a?(Numeric) ? 'rjust' : 'ljust'
            cells << item.to_s.send(justifier, widths[i])
          end
          '  ' + cells.join('  ') + '  '
        end

        def build_footer(nrows, elapsed)
          rows_label = nrows == 1 ? 'row' : 'rows'
          "#{nrows} #{rows_label} selected. (%.2f sec)" % elapsed
        end
      end
    end
  end
end
