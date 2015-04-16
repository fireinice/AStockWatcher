# coding: utf-8
require "uri"
require_relative "stock"

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

class YahooHistory
  #http://table.finance.yahoo.com/table.csv?a=0&b=1&c=2012&d=3&e=19&f=2012&s=600000.ss
  # @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")
  def initialize(base_url)
    @base_url = base_url
    # @fetchAgent = WWW::Mechanize.new { |agent|
    #   agent.user_agent_alias = 'Linux Mozilla'
    #   agent.max_history = 0
    # }
  end

  def getURL(stock, beginDate, endDate)
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
    url = @base_url + "?" + URI.encode_www_form(infos)
  end

  def fetchData(stock, begDate, endDate)
    url = self.getURL(stock, begDate, endDate)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host)
    http.open_timeout = 5
    res = Net::HTTP.get_response(uri)
    remote_data = res.body if res.is_a?(Net::HTTPSuccess)
  end

  def getStatus(stock, begDate ,endDate)
    remote_data = self.fetchData(stock, begDate, endDate)
    self.parseData(remote_data)
  end

  def parseData(rdata)
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

class TrendingCalculator
  def self.calc(begLineDate, begLinePrice, endLineDate, endLinePrice, highLineDate, highLinePrice, stockHistory)
    priceDiff = endLinePrice - begLinePrice
    tDays = stockHistory.getTradingDays(begLineDate, endLineDate)
    if tDays < 1
      return nil
    end
    tDiff = priceDiff / (tDays - 1)
    tHeight = 0
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
  end
end

if $0 == __FILE__
  yahooHistoryBaseURL = "http://table.finance.yahoo.com/table.csv"
  historyInterface = YahooHistory.new(yahooHistoryBaseURL)
  stock = Stock.new("600000", "sh", 1, 100)
  begDate = Date.new(2015, 4, 1)
  endDate = Date.new(2015, 4, 15)
  records = historyInterface.getStatus(stock, begDate, endDate)
  stock_history = StockHistory.new(records)
  begDate = Date.new(2015, 4, 3)
  endDate = Date.new(2015, 4, 16)
  puts stock_history.getTradingDays(begDate, endDate)

end
