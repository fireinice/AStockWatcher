#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require "yaml"

class CFGController
  def initialize(filename)
    @stocks = {}
    @filename = filename

    if not File.exist?(filename)
      @cfg = {}
      @cfg["Stocks"] = []
    else
      @cfg = YAML.load(File.open(filename))
      @cfg["Stocks"].each do |stock|
        @stocks[stock.ref_value] = stock
      end
    end
  end
  attr_reader :cfg

  def updateCFG()
    @cfg["Stocks"] = @stocks.values
    File.open( @filename, 'w' ) do |out|
      YAML.dump(@cfg , out )
    end
  end

  def updateStockTrendingInfo(market, code, begDate, trending_line, dayPriceDiff, amp)
    stockKey = Stock.get_ref_value(market, code)
    if not @stocks.has_key?(stockKey)
      @stocks[stockKey] = Stock.new(code, market)
    end
    @stocks[stockKey].update_trending_info(begDate, trending_line, dayPriceDiff, amp)
    self.updateCFG()
  end

  def updateStockBuyInfo(market, code, price, quantity)
    stockKey = Stock.get_ref_value(market, code)
    if not @stocks.has_key?(stockKey)
      @stocks[stockKey] = Stock.new(code, market)
    end
    @stocks[stockKey].update_buy_info!(price, quantity)
    self.updateCFG()
  end

  def updateStock(stock)
    stockKey = stock.ref_value
    @stocks[stockKey] = stock
    self.updateCFG()
  end

  def getAllStocks()
    return @stocks.values
  end

  def getStock(market, code)
    stockKey = Stock.get_ref_value(market, code)
    if not @stocks.has_key?(stockKey)
      @stocks[stockKey] = Stock.new(code, market)
    end
    return @stocks[stockKey]
  end

  def addStock(market, code)
    stockKey = Stock.get_ref_value(market, code)
    @stocks[stockKey] = Stock.new(code, market)
    self.updateCFG()
  end

  def addStock(market, code, price, quantity)
    stockKey = Stock.get_ref_value(market, code)
    @stocks[stockKey] = Stock.new(code, market)
    @stocks[stockKey].update_buy_info!(price, quantity)
    self.updateCFG()
  end

  def delStock(market, code)
    stockKey = Stock.get_ref_value(market, code)
    @stocks.delete(stockKey)
    self.updateCFG()
  end

  def setCharges(charge_name, charge_money)
    charges_config = @cfg["CommonConfig"]
    if not charges_config.has_key?(charge_name)
      return charges_config.keys
    end
    charges_config[charge_name] = charge_money.to_f
    self.updateCFG()
  end
end
