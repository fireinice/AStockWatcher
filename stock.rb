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
  @@end_time = Time.new(now.year, now.mon, now.mday, 15, 00, 00)

  def self.is_now_in_trading_time?()
    return (Time.now >= @@start_time and Time.now <= @@end_time)
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

  attr_reader :stock

  def records
    records = []
    @dates.each do |date|
      records << @records[date] if  not @records[date].nil?
    end
    return records
  end

  def trading_days
    @dates
  end

  def self.build_history(stock, begin_date, end_date)
    records = @@interface.get_status(stock, begin_date, end_date)
    return nil if records.nil? or records.empty?
    self.new(stock, records)
  end

  def extend_history!(begin_date, end_date)
    need_extend = false
    if @dates.nil? or @dates.empty?
      need_extend = true
    else
      begin_date < @dates[0] ? need_extend = true : begin_date = @dates[0]
      end_date > @dates[-1] ? need_extend = true : end_date = @dates[-1]
    end
    return if not need_extend
    records_list = @@interface.get_status(@stock, begin_date, end_date)
    return nil if records_list.nil?
    @records = {}
    @dates = []
    records_list.each { |record| @dates << record.date; @records[record.date] = record }
    @dates.sort!
  end

  def get_records_by_range(begin_date, end_date)
    extend_history!(begin_date, end_date) if not @stock.nil?
    @records.values.select{ |record| record.date <= end_date and record.date >= begin_date }
  end

  def get_record_by_reverse_gap_days gap_days
    @records[@dates[gap_days]]
  end

  def set_record_by_date!(date, value)
    extend_history!(date, @dates[-1]) if date < @dates[0] if not @stock.nil?
    extend_history!(@dates[0], date) if date > @dates[-1] if not @stock.nil?
    @records[date] = value
  end

  def get_record_by_date(date)
    extend_history!(date, @dates[-1]) if date < @dates[0] if not @stock.nil?
    extend_history!(@dates[0], date) if date > @dates[-1] if not @stock.nil?
    @records[date]
  end

  def get_last_record
    @records[@dates[-1]]
  end

  def is_trading_day?(date)
    trading_day = @dates.find { |a_date| a_date == date }
    return (not trading_day.nil?)
  end

  def getTradingDays(begin_date, end_date)
    count = 0
    if begin_date > end_date
      return 0
    end
    if @dates[0] > begin_date
      #or  @dates[-1] < endStr #yesterday maybe not a trading
      return -1
    end

    today = Date.today
    if end_date >= today and @dates[-1] < today
      trading_day_infos = SinaTradingDay.get_status(@stock)
      count = 1 if Date.parse(trading_day_infos[:date]) == today
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
  @@interface = SinaTradingDay

  def initialize(code, market=nil)
    if code.nil? or code.length != 6
      raise ArgumentError, "Bad data"
    end
    code, market = Stock.parse_code(code) if market.nil?
    @code = code
    @market = market
    @history = nil
  end

  def self.interface=(inteface_kls)
    @@interface = inteface_kls
  end

  def self.parse_code code
    v = []
    mkt = code.start_with?('6') ? 'sh' : 'sz'
    return code, mkt
  end

  attr_reader :code, :market, :buy_price, :buy_quantity, :costing,
              :name, :deal, :y_close, :t_open, :t_date, :t_date_str,
              :pb, :pe,
              :last_update_date,
              :history

  def encode_with coder
    instance_variables.map{|vname| coder[vname.to_s()[1..-1]] = instance_variable_get vname if vname != :@history and vname != :t_date_str}
  end

  def extend_history!(begin_date, end_date)
    if not hasHistory?
      @history = StockHistory.build_history(self, begin_date, end_date)
      return false if @history.nil?
    else
      ret = @history.extend_history!(begin_date, end_date)
      return false if ret.nil?
    end
    return true
  end

  def hasHistory?()
    not @history.nil?
  end

  def updateHistory(stockHistory)
    @history = stockHistory
  end

  def update_buy_info!(price, quantity)
    @buy_price = price
    @buy_quantity = quantity
    @costing = @buy_price
    self
  end

  def update_trading!()
    info = @@interface.get_status(self)
    self.update_day_trading_info!(info)
  end

  def update_day_trading_info!(day_trading_hash)
    return self if day_trading_hash.nil?
    @name = day_trading_hash[:name]
    @deal = day_trading_hash[:deal].to_f
    @deal = nil if @deal < 0.01
    @y_close = day_trading_hash[:y_close].to_f
    @y_close = nil if @y_close < 0.01
    @t_open = day_trading_hash[:t_open].to_f
    @t_open = nil if @t_open < 0.01
    if @t_date_str != day_trading_hash[:date]
      @t_date_str = day_trading_hash[:date]
      @t_date = Date.parse(@t_date_str)
    end
    @pb = day_trading_hash[:pb] if not day_trading_hash[:pb].nil?
    @pe = day_trading_hash[:pe] if not day_trading_hash[:pe].nil?
    self
  end

  def Stock.get_ref_value(market, code)
    return market + code
  end

  def Stock.initFromHash(info_hash)
    stock = Stock.new(info_hash["code"], info_hash["market"])
    if info_hash["buy_quantity"]
      stock.update_buy_info!(info_hash["buy_price"], info_hash["buy_quantity"])
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
