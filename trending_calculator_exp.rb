# coding: utf-8
require 'date'
require 'set'
require_relative "stock"
require_relative "interface"

class TrendingCalculatorAdapter
  def self.to_inner!(stock)
    for date in stock.history.trading_days do
      value = stock.history.get_record_by_date(date)
      value.high = Math.log(value.high)
      value.low = Math.log(value.low)
      value.open = Math.log(value.open)
      value.close = Math.log(value.close)
      stock.history.set_record_by_date!(date, value)
      value = stock.history.get_record_by_date(date)
      stock.trending_type = :exp
    end
  end
end
