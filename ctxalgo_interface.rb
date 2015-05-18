# coding: utf-8
require_relative "interface"
#http://ctxalgo.com/api

class StockList < WebInterface
  @@base_url = "http://ctxalgo.com/api/stocks"
  def self.get_status()
    url = @@base_url
    remote_data = self.fetch_data(url)
    return nil if remote_data.nil?
    self.parse_data(remote_data)
  end

  def self.parse_data(rdata)
    stocks = JSON.parse(rdata)
    return stocks
  end
end

class StockPlate < WebInterface
  @@base_url = "http://ctxalgo.com/api/plate_of_stocks"

  def self.get_url(stock_list, date)
    stock_infos = []
    stock_list.each { |stock| stock_infos << stock.market + stock.code  }
    url = @@base_url + "/" + stock_infos.join(";") + "?date=" + date.strftime('%F')
  end

  def self.get_status(stock, date=Date.today)
    stock_list = [stock]
    return get_status_batch(stock_list, date)
  end

  def self.get_status_batch(stock_list, date=Date.today)
    url = get_url(stock_list, date)
    remote_data = self.fetch_data(url)
    return nil if remote_data.nil?
    infos = self.parse_data(remote_data)
  end

  def self.parse_data(rdata)
    stocks = JSON.parse(rdata)
    return stocks
  end
end
