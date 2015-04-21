# coding: utf-8
#
#  file::     stock.rb
#  brief::    A Stock Watcher
#
#  author::   fireinice(fireinice@gmail.com)
#  bug::      No known bugs.
#
#   $Date: 2010/01/11 08:32:57 $
#   $Revision: 1.0 $
#
#--
#!/usr/bin/env ruby
#++
#
require "net/http"
require "uri"
require_relative "stock_record"
require_relative "interface"

class AStockMarket
  #A股市场
  now = Time.now
  @@start_time = Time.new(now.year, now.mon, now.mday, 9, 30, 00)
  @@end_time = Time.new(now.year, now.mon, now.mday, 3, 00, 00)

  def self.is_now_in_trading_time?()
    return if Time.now >= @@start_time and Time.now <= @@end_time
  end

  def self.is_now_before_trading_time?()
    return Time.now < @@start_time
  end

  def self.is_now_after_trading_time?()
    return Time.now > @@end_time
  end
end

class StockHistory
  @@interface = YahooHistory
  def initialize(stock, records_list)
    @records = {}
    @dates = []
    records_list.each { |record| @dates << record.date; @records[record.date] = record }
    @dates.sort!
    @stock = stock
  end

  def self.build_history(stock, begin_date, end_date)
    records = @@interface.getStatus(stock, begin_date, end_date)
    self.new(stock, records)
  end

  def extend_history!(stock, begin_date, end_date)
    @stock = stock
    need_extend = false
    begin_date < @dates[0] ? need_extend = true : begin_date = @dates[0]
    end_date > @dates[-1] ? need_extend = true : end_date = @dates[-1]
    return if not need_extend
    records_list = @@interface.getStatus(stock, begin_date, end_date)
    @records = {}
    @dates = []
    records_list.each { |record| @dates << record.date; @records[record.date] = record }
    @dates.sort!
  end

  def get_records_by_range(begin_date, end_date)
    extend_history!(@stock, begin_date, end_date) if not @stock.nil?
    @records.values.select{ |record| record.date <= end_date and record.date >= begin_date }
  end

  def get_record_by_date(date)
    extend_history!(date, @dates[-1]) if date < @dates[0] if not @stock.nil?
    extend_history!(@dates[0], date) if date > @dates[-1] if not @stock.nil?
    @records[date]
  end

  def get_last_record
    @records[@dates[-1]]
  end

  def getTradingDays(begin_date, end_date)
    count = 0
    if begin_date > end_date
      return 0
    end
    if @dates[0] > begin_date
      #or  @dates[-1] < endStr #yesterday maybe not a trending
      return -1
    end

    @dates.each do |date|
      if date < begin_date
        next
      elsif date > end_date
        return count
      end
      count += 1
    end
    return count
  end
end


class Stock
  def initialize(code, market)
    if not code or not market
      raise ArgumentError, "Bad data"
    end
    @code = code
    @market = market
    @history = nil
  end

  attr_reader :code, :market, :buy_price, :buy_quantity, :costing,
              :calc_begin_date, :calc_begin_price, :day_price_diff, :trending_amp,
              :last_update_date,
              :history

  def encode_with coder
    instance_variables.map{|vname| coder[vname.to_s()[1..-1]] = instance_variable_get vname if vname != :@history}
  end

  def extend_history!(begin_date, end_date)
    if not hasHistory?
      @history = StockHistory.build_history(self, begin_date, end_date)
    else
      @history.extend_history!(self, begin_date, end_date)
    end
  end

  def hasHistory?()
    not @history.nil?
  end

  def updateHistory(stockHistory)
    @history = stockHistory
  end

  def updateBuyInfo(price, quantity)
    @buy_price = price
    @buy_quantity = quantity
    @costing = @buy_price
  end

  def updateTrendingInfo(calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp)
    @calc_begin_date = calcBeginDate
    @calc_begin_price = calcBeginPrice
    @day_price_diff = dayPriceDiff
    @trending_amp = trendingAmp
  end

  def Stock.get_ref_value(market, code)
    return market + code
  end

  def Stock.initFromHash(info_hash)
    stock = Stock.new(info_hash["code"], info_hash["market"])
    if info_hash["buy_quantity"]
      stock.updateBuyInfo(info_hash["buy_price"], info_hash["buy_quantity"])
    end
    return stock
  end

  def sum
    @buy_price * @buy_quantity
  end


  def calcCosting(charges_ratio, tax_ratio, other_charge)
    if not @buy_quantity
      @costing = 0
      return @costing
    end
    @costing = (self.sum * ( 1 + (charges_ratio * 2 + tax_ratio) * 0.01 )  + other_charge) / @buy_quantity
  end

  def to_hash
    info = {}
    info["market"] = @market
    info["code"] = @code
    info["buy_price"] = @buy_price
    info["buy_quantity"] = @buy_quantity
    return info
  end

  def ref_value
    @market + @code
  end


end

class Account
  def initialize(charges_ratio, tax_ratio, other_charge)
    if not charges_ratio or not tax_ratio or not other_charge
      raise ArgumentError, "Bad data"
    end
    @all_stock = []
    @charges_ratio = charges_ratio
    @tax_ratio = tax_ratio
    @other_charge = other_charge
  end

  attr_reader :all_stock, :charges_ratio, :tax_ratio, :other_charge

  def addStock(stock)
    @all_stock << stock
  end

  def Account.initChargesFromHash(info_hash)
    Account.new(info_hash["charges_ratio"], info_hash["tax_ratio"],
                info_hash["other_charge"])
  end

  def Account.buildFromCfg(cfg_yml)
    account = Account.initChargesFromHash(cfg_yml["CommonConfig"])
    basket = cfg_yml["Stocks"]
    basket.each do |stock|
      if not stock.buy_quantity.nil? and stock.buy_quantity > 0
        stock.calcCosting(account.charges_ratio, account.tax_ratio, account.other_charge)
        account.addStock(stock)
      end
    end
    return account
  end

end
