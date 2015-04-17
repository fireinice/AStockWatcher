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
  def self.calc(stockHistory, begLineDate, begLinePrice, endLineDate, endLinePrice, highLineDate, highLinePrice)
    stockHistory = stock.history
    priceDiff = endLinePrice - begLinePrice
    tDays = stockHistory.getTradingDays(begLineDate, endLineDate)
    if tDays < 1
      return false
    end
    tDiff = priceDiff / (tDays - 1)
    begDiffDate = endLineDate
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
    return [begDiffDate, tDiff, tAmp]
  end
end
