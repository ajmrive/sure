# Buckets a single category's flows across a period into a bar-chartable series
# with automatic granularity (daily / weekly / monthly) so long periods stay
# legible without horizontal scrolling.
#
#   amounts / previous_amounts: [[Date, BigDecimal], ...]
#     (already converted to family currency and signed: expenses positive)
#
# The previous-period series is aligned bucket-by-bucket by shifting each
# current bucket range back by the period length, so bucket i of "previous"
# is the directly-comparable window before bucket i of "current".
class CategoryTimeSeries
  DAILY_MAX_DAYS = 62   # ~2 months
  WEEKLY_MAX_DAYS = 366 # ~1 year

  attr_reader :start_date, :end_date

  def initialize(start_date:, end_date:, amounts:, previous_amounts: [])
    @start_date = start_date
    @end_date = end_date
    @amounts = amounts
    @previous_amounts = previous_amounts
  end

  def granularity
    span = (end_date - start_date).to_i
    if span <= DAILY_MAX_DAYS
      :daily
    elsif span <= WEEKLY_MAX_DAYS
      :weekly
    else
      :monthly
    end
  end

  def buckets
    @buckets ||= begin
      offset = (end_date - start_date).to_i + 1
      max = bucket_ranges.map { |range| sum_in(@amounts, range) }.max
      bucket_ranges.map do |range|
        value = sum_in(@amounts, range)
        prev_range = (range.first - offset)..(range.last - offset)
        {
          start: range.first,
          end: range.last,
          value: value,
          prev_value: sum_in(@previous_amounts, prev_range),
          is_max: max&.positive? && value == max
        }
      end
    end
  end

  def total
    @total ||= buckets.sum { |bucket| bucket[:value] }
  end

  def average
    return 0 if buckets.empty?

    total / buckets.size
  end

  def max_value
    buckets.map { |bucket| bucket[:value] }.max || 0
  end

  # Largest value across both series — used so current and previous bars share a scale.
  def scale_max
    candidates = buckets.flat_map { |bucket| [ bucket[:value], bucket[:prev_value] ] }
    candidates.map(&:abs).max || 0
  end

  private
    def sum_in(amounts, range)
      amounts.sum { |(date, amount)| range.cover?(date) ? amount : 0 }
    end

    def bucket_ranges
      case granularity
      when :daily
        (start_date..end_date).map { |day| day..day }
      when :weekly
        weekly_ranges
      else
        monthly_ranges
      end
    end

    def weekly_ranges
      ranges = []
      cursor = start_date
      while cursor <= end_date
        ranges << (cursor..[ cursor + 6, end_date ].min)
        cursor += 7
      end
      ranges
    end

    def monthly_ranges
      ranges = []
      cursor = start_date.beginning_of_month
      while cursor <= end_date
        ranges << ([ cursor, start_date ].max..[ cursor.end_of_month, end_date ].min)
        cursor = cursor.next_month.beginning_of_month
      end
      ranges
    end
end
