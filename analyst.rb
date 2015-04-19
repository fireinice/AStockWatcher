# coding: utf-8
require_relative "stock"
require_relative "calculator"
require_relative "interface"

class StockAnalyst
  def self.updateStockHistory(stock,startDate, endDate, ampDate)
    dates = [startDate, endDate, ampDate]
    dates.sort!
    begDate = dates[0]
    endDate =  Date.today.prev_day
    records = YahooHistory.getStatus(stock, begDate, endDate)
    stock.updateHistory(StockHistory.new(records))
  end

  def self.analyzeTrending(stock, startDate, startPrice,
                           endDate, endPrice, ampDate, ampPrice)
    if not stock.hasHistory?
      self.updateStockHistory(stock, startDate, endDate, ampDate)
    end
    calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp =
                                 TrendingCalculator.calc(
                                   stock.history, startDate, startPrice,
                                   endDate, endPrice,
                                   ampDate, ampPrice)
    if not calcBeginDate.nil?
      stock.updateTrendingInfo(calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp)
    else
      puts "date error"
    end
  end
end
