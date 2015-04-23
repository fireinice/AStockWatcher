# coding: utf-8
require_relative "stock"
require_relative "interface"
class Stock
  attr_reader :trending_base_date, :trending_line, :day_price_diff, :trending_amp
  def update_trending_info(trending_base_date, trending_line,
                           day_price_diff, trending_amp)
    @trending_base_date = trending_base_date
    @trending_line = trending_line
    @day_price_diff = day_price_diff
    @trending_amp = trending_amp
  end
end

class TrendingCalculator
  def self.update_trending(stock)
    return if not stock.trending_base_date or not stock.trending_line or
      not stock.day_price_diff or not stock.trending_amp
    end_date = Date.today
    begin_date = stock.trending_base_date
    return if begin_date == end_date and not AStockMarket.is_now_after_trading_time?
    extended = stock.extend_history!(begin_date, end_date)
    return if not extended
    gap_trading_days = stock.history.getTradingDays(begin_date, end_date)
    # end_date include then we should minus 1 for gap
    gap_trading_days -= 1 if stock.history.get_last_record.date >= end_date
    # after trading time, we caculator next day
    if AStockMarket.is_now_after_trading_time?
      end_date += 1
      gap_trading_days += 1
    end
    # if base date is not a trending day, we need to minus it
    gap_trading_days -= 1 if not stock.history.is_trading_day?(stock.trending_base_date)
    return if gap_trading_days <= 0
    trending_line = stock.trending_line + stock.day_price_diff * gap_trading_days
    stock.update_trending_info(end_date, trending_line,
                               stock.day_price_diff, stock.trending_amp)
  end

  def self.analyze(stock, start_date, start_price,
                   end_date, end_price, amp_date, amp_price)
    dates = [start_date, end_date, amp_date]
    dates.sort!
    begin_date = dates[0]
    end_date =  Date.today.prev_day
    stock.extend_history!(start_date, end_date)
    calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp =
                                                 calc(
                                                   stock,
                                                   start_date, start_price,
                                                   end_date, end_price,
                                                   amp_date, amp_price)
    if not calcBeginDate.nil?
      stock.update_trending_info(calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp)
    else
      puts "date error"
    end
  end


  def self.get_gap(stock, infos)
    current_price = infos[stock.code][3].to_f
    return nil if not stock.trending_base_date or current_price < 0.01
    end_date = Date.today
    end_date = end_date + 1 if AStockMarket.is_now_after_trading_time?
    update_trending(stock) if end_date > stock.trending_base_date
    gap = current_price - stock.trending_line
    gap_ratio = gap * 100 / current_price
    if gap < 0
      amp = stock.trending_line - stock.trending_amp
      amp_type = 'l'
    else
      amp = stock.trending_line + stock.trending_amp
      amp_type = 'u'
    end
    amp_ratio = (current_price - amp) * 100 / current_price
    return [stock.trending_line, gap_ratio, amp, amp_ratio, amp_type]
  end

  def self.calc(stock, begLineDate, begLinePrice, endLineDate, endLinePrice, highLineDate, highLinePrice)
    priceDiff = endLinePrice - begLinePrice
    tDays = stock.history.getTradingDays(begLineDate, endLineDate)
    if tDays < 1
      return nil
    end
    tDiff = priceDiff / (tDays - 1)
    begDiffDate = endLineDate
    begDiffPrice = endLinePrice
    case begLineDate <=> highLineDate
    when -1
      tDays = stock.history.getTradingDays(begLineDate, highLineDate)
    when 1
      tDays = -stock.history.getTradingDays(highLineDate, begLineDate)
    when 0
      tDays = 1
    end
    highLineDatePrice = begLinePrice + tDiff * (tDays - 1)
    tAmp = highLinePrice - highLineDatePrice
    return [begDiffDate, begDiffPrice, tDiff, tAmp]
  end
end

if $0 == __FILE__
  require_relative "stock_cmd"
  cfg_file = CFGController.new("stock.yml")
  cfg_file.getAllStocks.each { |stock| TrendingCalculator.update_trending(stock) }
  cfg_file.updateCFG()
end
