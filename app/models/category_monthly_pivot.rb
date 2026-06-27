# Presentation math over an already-aggregated category x month pivot.
#
# Input rows follow the income_statement signing convention:
#   expenses are POSITIVE, income is NEGATIVE.
#
#   rows: [{ category: String, months: { Date => BigDecimal }, total: BigDecimal }, ...]
#   months: [Date, ...]  (each beginning_of_month, in display order)
#
# This object stays free of ActiveRecord/params so the accountant-style
# metrics (income vs expense totals, net, savings rate, per-row average and
# per-cell deviation) can be unit-tested with plain hashes.
class CategoryMonthlyPivot
  # A month whose magnitude is this far from its row average gets an arrow.
  DEVIATION_THRESHOLD = 0.25 # 25%

  attr_reader :months, :rows

  def initialize(months:, rows:)
    @months = months
    @rows = rows
  end

  # Rows augmented with a per-row monthly average and per-cell deviation metadata.
  def rows_with_metrics
    rows.map do |row|
      avg = average(row[:total])
      cells = months.index_with { |month| cell_metrics(row.dig(:months, month) || 0, avg) }
      row.merge(avg: avg, cells: cells)
    end
  end

  def month_expense_totals
    @month_expense_totals ||= months.index_with { |month| rows.sum { |row| positive(row.dig(:months, month)) } }
  end

  def month_income_totals
    @month_income_totals ||= months.index_with { |month| rows.sum { |row| negative(row.dig(:months, month)) } }
  end

  def month_net_totals
    @month_net_totals ||= months.index_with { |month| month_income_totals[month] - month_expense_totals[month] }
  end

  def savings_rates
    @savings_rates ||= months.index_with { |month| savings_rate(month_income_totals[month], month_expense_totals[month]) }
  end

  def total_expense
    @total_expense ||= month_expense_totals.values.sum
  end

  def total_income
    @total_income ||= month_income_totals.values.sum
  end

  def total_net
    total_income - total_expense
  end

  def overall_savings_rate
    savings_rate(total_income, total_expense)
  end

  def avg_expense = average(total_expense)
  def avg_income  = average(total_income)
  def avg_net     = average(total_net)

  private
    def average(value)
      return 0 if months.empty?
      value / months.size
    end

    def positive(value) = (value && value > 0) ? value : 0
    def negative(value) = (value && value < 0) ? -value : 0

    # Net over income, as a rounded percentage. Nil when there is no income
    # (a savings rate is meaningless without an income base).
    def savings_rate(income, expense)
      return nil unless income && income > 0

      ((income - expense).to_f / income * 100).round(1)
    end

    # Compares a cell's magnitude to its row's average magnitude.
    def cell_metrics(value, avg)
      avg_magnitude = avg.abs
      pct = avg_magnitude.zero? ? 0 : ((value.abs - avg_magnitude).to_f / avg_magnitude * 100)

      flag =
        if avg_magnitude.zero? || value == 0
          nil
        elsif pct >= DEVIATION_THRESHOLD * 100
          :up
        elsif pct <= -DEVIATION_THRESHOLD * 100
          :down
        end

      { value: value, deviation_pct: pct.round, flag: flag }
    end
end
