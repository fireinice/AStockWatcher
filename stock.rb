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

class StockRecord
  def initialize(date:, open:, close:, high:, low:, vol:, adj_close:)
    @date = date
    @open = open
    @close = close
    @high = high
    @low = low
    @vol = vol
    @adj_close = adj_close
  end
  attr_reader :date, :open, :close, :high, :low, :vol, :adj_close
end

class StockHistory
  def initialize(records_list)
    @records = records_list
    @dates = []
    @records.each { |record| @dates << record.date  }
    @dates.sort!
  end

  def getTradingDays(beginDate, endDate)
    count = 0
    begStr = beginDate.strftime('%F')
    endStr = endDate.strftime('%F')
    if begStr >= endStr
      return 0
    end
    if @dates[0] > begStr or  @dates[-1] < endStr
      return -1
    end

    @dates.each do |dateStr|
      if dateStr < begStr
        next
      elsif dateStr > endStr
        count += 1
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
              :calc_begin_date, :day_price_diff, :trending_amp,
              :history

  def hasHistory?()
    @history.nil?
  end

  def updateHistory(stockHistory)
    @history = stockHistory
  end

  def updateBuyInfo(price, quantity)
    @buy_price = price
    @buy_quantity = quantity
    @costing = @buy_price
  end

  def updateTrendingInfo(calcBeginDate, dayPriceDiff, trendingAmp)
    @calc_begin_date = calcBeginDate
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
    basket.each do |stock_info|
      stock = Stock.initFromHash(stock_info)
      if stock.buy_quantity > 0
        stock.calcCosting(account.charges_ratio, account.tax_ratio, account.other_charge)
        account.addStock(stock)
      end
    end
    return account
  end

end
