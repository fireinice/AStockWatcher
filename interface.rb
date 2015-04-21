# coding: utf-8
require "iconv"
require "uri"
require_relative "stock_record"

class StockHistoryBase
  #http://table.finance.yahoo.com/table.csv?a=0&b=1&c=2012&d=3&e=19&f=2012&s=600000.ss
  # @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")
  @@base_url = "http://table.finance.yahoo.com/table.csv"

  # def initialize(base_url)
  #   @base_url = base_url
  #   # @fetchAgent = WWW::Mechanize.new { |agent|
  #   #   agent.user_agent_alias = 'Linux Mozilla'
  #   #   agent.max_history = 0
  #   # }
  # end

  def self.getURL(stock, beginDate, endDate)
    market = stock.market
    if stock.market == 'sh'
      market = 'ss'
    end
    stockName = stock.code + "." + market
    infos = {}
    infos['a'] = beginDate.mon - 1
    infos['b'] = beginDate.mday
    infos['c'] = beginDate.year
    infos['d'] = endDate.mon - 1
    infos['e'] = endDate.mday
    infos['f'] = endDate.year
    infos['s'] = stockName
    url = @@base_url + "?" + URI.encode_www_form(infos)
  end

  def self.fetchData(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host)
    http.open_timeout = 5
    res = Net::HTTP.get_response(uri)
    remote_data = res.body if res.is_a?(Net::HTTPSuccess)
  end

  def self.getStatus(stock, begDate, endDate)
    url = self.getURL(stock, begDate, endDate)
    remote_data = self.fetchData(url)
    self.parseData(remote_data)
  end

  def self.parseData(rdata)
    records = []
    first = true
    rdata.split("\n").each do |dataLine|
      if first # skip first line
        first = false
        next
      end
      infos = dataLine.split(",")
      info_hash = {}
      info_hash[:vol] = infos[5].to_i
      if info_hash[:vol] == 0 #volume is 0
        next
      end
      info_hash[:date] = infos[0]
      info_hash[:open] = infos[1].to_f
      info_hash[:high] = infos[2].to_f
      info_hash[:low] = infos[3].to_f
      info_hash[:close] = infos[4].to_f
      info_hash[:adj_close] = infos[6].to_f
      records << StockRecord.new(info_hash)
    end
    return records
  end
end

class IFengHistory < StockHistoryBase
  @@base_url = "http://api.finance.ifeng.com/akdaily/?code=%s&type=last"
  def self.getURL(stock, beginDate, endDate)
    stockName = stock.market+stock.code
    url = sprintf(@@base_url, stockName)
  end
end

class YahooHistory < StockHistoryBase
  @@base_url = "http://table.finance.yahoo.com/table.csv"
end


class WebInfo
  @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")
  @@inter_name = ["股票名", "今开", "昨收", "报价", "最高价", "最低价", "竞买", "竞卖", "成交量",
                  "成交金额", "买一量", "买一", "买二量", "买二", "买三量", "买三", "买四量", "买四",
                  "买五量", "买五", "卖一量", "卖一", "卖二量", "卖二", "卖三量", "卖三",
                  "卖四量", "卖四", "卖五量", "卖五", "日期", "时间"]
  # http://hq.sinajs.cn/list=sz002238,sz000033
  def initialize(base_url)
    @base_url = base_url
    # @fetchAgent = WWW::Mechanize.new { |agent|
    #   agent.user_agent_alias = 'Linux Mozilla'
    #   agent.max_history = 0
    # }
  end

  def getURL(stockList)
    stock_infos = []
    stockList.each { |stock| stock_infos << stock.market + stock.code  }
    url = @base_url + stock_infos.join(",")
  end

  def fetchData(stockList)
    url = self.getURL(stockList)
    # remote_data = @fetchAgent.get_file(url)
    remote_data = Net::HTTP.get URI.parse(url)
    remote_data = @@decoder.iconv(remote_data)
  end

  def getStatus(stockList)
    remote_data = self.fetchData(stockList)
    infos = self.parseData(remote_data)
  end

  def parseData(rdata)
    info_hash = {}
    rdata.split("\n").each do |dataLine|
      data_list = dataLine.split("=")
      code = data_list[0][/\d+/]
      info_str = data_list[1].delete("\";")
      infos = info_str.split(",")
      info_hash[code] = infos
    end
    return info_hash
  end
end
