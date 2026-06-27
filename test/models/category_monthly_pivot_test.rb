require "test_helper"

class CategoryMonthlyPivotTest < ActiveSupport::TestCase
  # Helper month keys (beginning_of_month)
  JAN = Date.new(2025, 1, 1)
  FEB = Date.new(2025, 2, 1)
  MAR = Date.new(2025, 3, 1)

  # Signing convention matches income_statement: expenses positive, income negative.
  def build(rows)
    CategoryMonthlyPivot.new(months: [ JAN, FEB, MAR ], rows: rows)
  end

  test "splits monthly totals into expenses, income and net by cell sign" do
    pivot = build([
      { category: "Comida", months: { JAN => 100, FEB => 100, MAR => 400 }, total: 600 },
      { category: "Nómina", months: { JAN => -2000, FEB => -2000, MAR => -2000 }, total: -6000 }
    ])

    assert_equal 100, pivot.month_expense_totals[JAN]
    assert_equal 400, pivot.month_expense_totals[MAR]
    assert_equal 2000, pivot.month_income_totals[JAN]
    # net = income - expense
    assert_equal 1900, pivot.month_net_totals[JAN]
    assert_equal 1600, pivot.month_net_totals[MAR]
  end

  test "computes period totals and per-month averages" do
    pivot = build([
      { category: "Comida", months: { JAN => 100, FEB => 100, MAR => 400 }, total: 600 },
      { category: "Nómina", months: { JAN => -2000, FEB => -2000, MAR => -2000 }, total: -6000 }
    ])

    assert_equal 600, pivot.total_expense
    assert_equal 6000, pivot.total_income
    assert_equal 5400, pivot.total_net
    # averages are per-month over the displayed range (3 months)
    assert_equal 200, pivot.avg_expense
    assert_equal 2000, pivot.avg_income
    assert_equal 1800, pivot.avg_net
  end

  test "savings rate is net over income, rounded, nil when no income" do
    pivot = build([
      { category: "Comida", months: { JAN => 500, FEB => 500, MAR => 500 }, total: 1500 },
      { category: "Nómina", months: { JAN => -1000, FEB => -1000, MAR => 0 }, total: -2000 }
    ])

    # JAN: income 1000, expense 500 -> 50%
    assert_equal 50.0, pivot.savings_rates[JAN]
    # MAR: no income -> nil
    assert_nil pivot.savings_rates[MAR]
    # overall: income 2000, expense 1500 -> 25%
    assert_equal 25.0, pivot.overall_savings_rate
  end

  test "flags cells that deviate from the row average" do
    pivot = build([
      { category: "Comida", months: { JAN => 100, FEB => 100, MAR => 400 }, total: 600 }
    ])

    row = pivot.rows_with_metrics.first
    assert_equal 200, row[:avg]

    # MAR is 400 vs avg 200 -> +100% over -> :up
    assert_equal :up, row[:cells][MAR][:flag]
    assert_equal 100, row[:cells][MAR][:deviation_pct]

    # JAN is 100 vs avg 200 -> -50% -> :down
    assert_equal :down, row[:cells][JAN][:flag]
  end

  test "no deviation flag for zero cells or zero average" do
    pivot = build([
      { category: "Empty", months: {}, total: 0 }
    ])

    row = pivot.rows_with_metrics.first
    assert_nil row[:cells][JAN][:flag]
  end
end
