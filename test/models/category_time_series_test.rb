require "test_helper"

class CategoryTimeSeriesTest < ActiveSupport::TestCase
  test "uses daily granularity for short periods" do
    series = CategoryTimeSeries.new(
      start_date: Date.new(2025, 6, 1),
      end_date: Date.new(2025, 6, 5),
      amounts: []
    )
    assert_equal :daily, series.granularity
    assert_equal 5, series.buckets.size
  end

  test "uses weekly granularity for medium periods" do
    series = CategoryTimeSeries.new(
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 3, 15), # 73 days
      amounts: []
    )
    assert_equal :weekly, series.granularity
    assert_equal 11, series.buckets.size # ceil(73 / 7)
  end

  test "uses monthly granularity for long periods" do
    series = CategoryTimeSeries.new(
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2025, 6, 30),
      amounts: []
    )
    assert_equal :monthly, series.granularity
    assert_equal 18, series.buckets.size # Jan 2024 .. Jun 2025
  end

  test "sums amounts into the right daily buckets and flags the max" do
    series = CategoryTimeSeries.new(
      start_date: Date.new(2025, 6, 1),
      end_date: Date.new(2025, 6, 5),
      amounts: [
        [ Date.new(2025, 6, 1), 10 ],
        [ Date.new(2025, 6, 1), 5 ],
        [ Date.new(2025, 6, 3), 20 ]
      ]
    )

    buckets = series.buckets
    assert_equal 15, buckets[0][:value]
    assert_equal 0, buckets[1][:value]
    assert_equal 20, buckets[2][:value]
    assert_equal 35, series.total
    assert_equal 7, series.average # 35 / 5 buckets

    # June 3rd is the biggest day
    assert buckets[2][:is_max]
    assert_not buckets[0][:is_max]
  end

  test "aligns previous period by shifting bucket ranges back one period length" do
    series = CategoryTimeSeries.new(
      start_date: Date.new(2025, 6, 1),
      end_date: Date.new(2025, 6, 5), # 5-day period -> offset 5 days
      amounts: [ [ Date.new(2025, 6, 1), 50 ] ],
      previous_amounts: [ [ Date.new(2025, 5, 27), 100 ] ] # June 1 shifted back 5 days
    )

    first = series.buckets.first
    assert_equal 50, first[:value]
    assert_equal 100, first[:prev_value]
  end

  test "scale_max considers both current and previous values" do
    series = CategoryTimeSeries.new(
      start_date: Date.new(2025, 6, 1),
      end_date: Date.new(2025, 6, 3),
      amounts: [ [ Date.new(2025, 6, 1), 30 ] ],
      previous_amounts: [ [ Date.new(2025, 5, 29), 80 ] ] # aligns to first bucket
    )
    assert_equal 80, series.scale_max
  end
end
