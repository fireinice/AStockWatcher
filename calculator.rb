# coding: utf-8
require_relative "stock"

class Caculator
  def initialize(account)
    @account = account
  end

  def getChargesForBuy(stock)
    stock.sum * @account.charges_ratio * 0.01 + @account.other_charge
  end

  def getChargesForSale(cur_info, stock)
    cur_price = cur_info[3].to_f
    cur_price * stock.buy_quantity * (@account.charges_ratio + @account.tax_ratio) * 0.01  + @account.other_charge
  end

  def getGrossProfit(cur_info, stock)
    cur_price = cur_info[3].to_f
    cur_price * stock.buy_quantity - stock.sum
  end


  def getProfit(cur_info, stock)
    g_profit = self.getGrossProfit(cur_info, stock) #毛利润
    buy_charges = self.getChargesForBuy(stock)
    sale_charges = self.getChargesForSale(cur_info, stock)
    profit = g_profit - buy_charges - sale_charges
  end

  def getProfitPercentage(profit, stock)
    profit / (stock.buy_price * stock.buy_quantity) * 100
  end

  def getAllProfit(infos)
    profits = {}
    @account.all_stock.each do |stock|
      profits[stock.code] = []
      info = infos[stock.code]
      profit = self.getProfit(info, stock)
      profit_percentage = self.getProfitPercentage(profit, stock)
      # profits[stock.code]  = %w[#{profit} #{profit_percentage}]
      profits[stock.code] << profit
      profits[stock.code] << profit_percentage
    end
    return profits
  end

  def dumpInfo(infos)
    values = infos.values
    values.each do |value|
      print "===================\n"
      if value.length != @@inter_name.length
        raise ArgumentError, "length error"
      end
      0.upto(value.length - 1) do |i|
        print "#{@@inter_name[i]}:\t"
        print "#{value[i]}\n"
      end
    end
  end
end

class TrendingCalculator
  def self.getGap(stock, infos)
    curPrice = infos[stock.code][3].to_f
    if stock.calc_begin_date.nil? or curPrice < 0.01
      return nil
    end
    begDate = stock.calc_begin_date
    endDate =  Date.today.prev_day
    if stock.hasHistory?
      history = stock.history
    else
      records = YahooHistory.getStatus(stock, begDate, endDate)
      history = StockHistory.new(records)
    end
    tDays = history.getTradingDays(begDate, endDate)
    base = stock.calc_begin_price + stock.day_price_diff * tDays
    gap = curPrice - base
    gapRatio = (curPrice - base) * 100 / curPrice
    if gap < 0
      amp = base - stock.trending_amp
      ampType = 'l'
    else
      amp = base + stock.trending_amp
      ampType = 'u'
    end
    ampRatio = (curPrice - amp) * 100 / curPrice
    return [base, gapRatio, amp, ampRatio, ampType]
  end

  def self.calc(stockHistory, begLineDate, begLinePrice, endLineDate, endLinePrice, highLineDate, highLinePrice)
    priceDiff = endLinePrice - begLinePrice
    tDays = stockHistory.getTradingDays(begLineDate, endLineDate)
    if tDays < 1
      return nil
    end
    tDiff = priceDiff / (tDays - 1)
    begDiffDate = endLineDate
    begDiffPrice = endLinePrice
    case begLineDate <=> highLineDate
    when -1
      tDays = stockHistory.getTradingDays(begLineDate, highLineDate)
    when 1
      tDays = -stockHistory.getTradingDays(highLineDate, begLineDate)
    when 0
      tDays = 1
    end
    highLineDatePrice = begLinePrice + tDiff * (tDays - 1)
    tAmp = highLinePrice - highLineDatePrice
    return [begDiffDate, begDiffPrice, tDiff, tAmp]
  end
end
