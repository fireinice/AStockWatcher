# coding: utf-8
require "iconv"
require "uri"
require 'net/http'
require 'json'
require_relative "stock_record"

class WebInterface
  def self.fetch_data(url)
    uri = URI.parse(url)
    res = nil
    http = Net::HTTP.new(uri.host)
    http.read_timeout = 3
    http.open_timeout = 5
    begin
      res = http.request_get(uri.request_uri)
    # rescue Net::ReadTimeout, Net::OpenTimeout, Zlib::BufError, SocketError
    rescue
      sleep(1)
      retry
    end
    remote_data = res.body if res.is_a?(Net::HTTPSuccess)
  end
end


class StockHistoryBase < WebInterface
  #http://api.finance.ifeng.com/akdaily/?code=sh000001&type=last
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

  def self.get_url(stock, beginDate, endDate)
    market = stock.market
    market = 'ss' if stock.market == 'sh'
    code = stock.code
    code = code[1..-1] if code.start_with?('0')

    stockName = code + "." + market
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

  def self.get_status(stock, begDate, endDate)
    url = self.get_url(stock, begDate, endDate)
    remote_data = self.fetch_data(url)
    return nil if remote_data.nil?
    self.parse_data(remote_data)
  end

  def self.parse_data(rdata)
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
  def self.get_url(stock, beginDate, endDate)
    stockName = stock.market+stock.code
    url = sprintf(@@base_url, stockName)
  end
end

class YahooHistory < StockHistoryBase
  @@base_url = "http://table.finance.yahoo.com/table.csv"
end

class TradingDay < WebInterface
  @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")
  @@base_url = nil
  @@inter_name = nil
  @@inter_name_hk = nil
  @@inter_keys_hk = nil
  @@inter_keys = nil
  @@hk_realtime_prefix = nil

  def self.get_url(stock_list)
    stock_infos = []
    stock_list.each do |stock|
      str = ""
      str += @@hk_realtime_prefix if "hk" == stock.market
      str += stock.market + stock.code
      stock_infos << str
    end
    url = @@base_url + stock_infos.join(",")
  end

end

class SinaTradingDay < WebInterface
  @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")
  @@base_url = "http://hq.sinajs.cn/list="
  @@inter_name = ["股票名", "今开", "昨收", "报价", "最高价", "最低价", "竞买", "竞卖", "成交量",
                  "成交金额", "买一量", "买一", "买二量", "买二", "买三量", "买三", "买四量", "买四",
                  "买五量", "买五", "卖一量", "卖一", "卖二量", "卖二", "卖三量", "卖三",
                  "卖四量", "卖四", "卖五量", "卖五", "日期", "时间"]
  @@inter_name_hk = %w(英文名 中文名 今开 昨收 最高价 最低价 报价 涨跌 振幅 竞买 竞卖 成交金额 成交量 市盈率 周息 年高点 年低点 日期 时间)
  @@inter_keys_hk = %i(name_e name t_open y_close high low deal change change_ratio buy sell turnover vol pe wir year_high year_low date time)
  @@inter_keys = %i( name t_open y_close deal high low buy sell vol turnover buy_vol1 buy1 buy_vol2 buy2 buy_vol3 buy3 buy_vol4 buy4 buy_vol5 buy5 sell_vol1 sell1 sell_vol2 sell2 sell_vol3 sell3 sell_vol4 sell4 sell_vol5 sell5 date time )
  # http://hq.sinajs.cn/list=sz002238,sz000033

  @@hk_realtime_prefix = "rt_"
  def self.get_url(stock_list)
    stock_infos = []
    stock_list.each do |stock|
      str = ""
      str = "rt_" if "hk" == stock.market
      str += stock.market + stock.code
      stock_infos << str
    end
    url = @@base_url + stock_infos.join(",")
  end

  def self.fetch_data(stock_list)
    url = self.get_url(stock_list)
    # remote_data = @fetchAgent.get_file(url)
    remote_data = self.fetch_data(url)
    remote_data = @@decoder.iconv(remote_data)
  end

  def self.get_status(stock)
    stock_list = [stock]
    infos = self.get_status_batch(stock_list)
    return infos.values[0]
  end

  def self.get_status_batch(stock_list)
    remote_data = self.fetch_data(stock_list)
    infos = self.parse_data(remote_data)
  end

  def self.update_stocks_batch(stock_list)
    infos = self.get_status_batch(stcok_list)
  end

  def self.parse_data(rdata)
    info_hash = {}
    rdata.split("\n").each do |data_line|
      data_list = data_line.split("=")
      market = data_list[0][/sz|sh|hk/]
      code = data_list[0][/\d+/]
      info_str = data_list[1].delete("\";")
      infos = info_str.split(",")
      stock_info = {}
      keys = @@inter_keys
      keys = @@inter_keys_hk if market == "hk"
      raise "data format not as expected" unless keys.size == infos.size
      infos.each_index do |i|
        v = infos[i]
        # v = v[0..-3] if @@inter_keys[i].to_s.include?("vol")
        # v = v[0..-5] if
        stock_info[keys[i]] = v
      end
      info_hash[code] = stock_info
    end
    return info_hash
  end
end

if $0 == __FILE__
  require_relative "stock"
  code = "00001"
  market = "hk"
  stock = Stock.new(code, market)
  stock.update_trading!()
  puts stock.deal
end
