require_relative "stock"
require_relative "calculator"

class StockAnalyst
  def self.updateStockHistory(stock,startDate, endDate, ampDate)
    dates = [startDate, endDate, ampDate]
    dates.sort!
    begDate = dates[0]
    endDate =  Date.today.prev_day
    records = historyInterface.getStatus(stock, begDate, endDate)
    stock.updateHistory(StockHistory.new(records))
  end

  def self.analyzeTrending(stock, startDate, startPrice,
                           endDate, endPrice, ampDate, ampPrice)
    if not stock.hasHistory?
      self.updateStockHistory(stock, startDate, endDate, ampDate)
    end
    calcBeginDate, dayPriceDiff, trendingAmp =
                                 TrendingCalculator.calc(
                                   stock.history, startDate, startPrice,
                                   endDate, endPrice,
                                   ampDate, ampPrice)
    stock.updateTrendingInfo(calcBeginDate, dayPriceDiff, trendingAmp)
  end
end
