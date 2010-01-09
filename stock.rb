$KCODE = 'u'
require 'mechanize'
require "iconv"
require "jcode"
require "rubygems"
require "colorize"
require "stringio"

class Stock
  def initialize(code, market, price, quantity)
    if not code or not market or not price or not quantity
      raise ArgumentError, "Bad data"
    end
    @code = code
    @market = market
    @buy_price = price
    @buy_quantity = quantity
    @costing = @buy_price
  end

  attr_reader :code, :market, :buy_price, :buy_quantity, :costing

  def Stock.initFromHash(info_hash)
    Stock.new(info_hash["code"], info_hash["market"],
              info_hash["buy_price"], info_hash["buy_quantity"])
  end

  def sum
    @buy_price * @buy_quantity
  end


  def calcCosting(charges_ratio, tax_ratio, comm_charge)
    @costing = (self.sum * ( 1 + (charges_ratio * 2 + tax_ratio) * 0.01 )  + comm_charge) / @buy_quantity
  end


end

class Account
  def initialize(charges_ratio, tax_ratio, comm_charge)
    if not charges_ratio or not tax_ratio or not comm_charge
      raise ArgumentError, "Bad data"
    end
    @all_stock = []
    @charges_ratio = charges_ratio
    @tax_ratio = tax_ratio
    @comm_charge = comm_charge
  end

  attr_reader :all_stock, :charges_ratio, :tax_ratio, :comm_charge

  def addStock(stock)
    @all_stock << stock
  end

  def Account.initChargesFromHash(info_hash)
    Account.new(info_hash["charges_ratio"], info_hash["tax_ratio"],
                info_hash["comm_charge"])
  end

  def Account.buildFromCfg(cfg_yml)
    account = Account.initChargesFromHash(cfg_yml["CommonConfig"])
    basket = cfg_yml["Stocks"]
    basket.each do |stock_info|
      stock = Stock.initFromHash(stock_info)
      stock.calcCosting(account.charges_ratio, account.tax_ratio, account.comm_charge)
      account.addStock(stock)
    end
    return account
  end

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
    @fetchAgent = WWW::Mechanize.new { |agent|
      agent.user_agent_alias = 'Linux Mozilla'
      agent.max_history = 0
    }
  end

  def getURL(stockList)
    stock_infos = []
    stockList.each { |stock| stock_infos << stock.market + stock.code  }
    url = @base_url + stock_infos.join(",")
  end

  def fetchData(stockList)
    url = self.getURL(stockList)
    remote_data = @fetchAgent.get_file(url)
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

class Caculator
  def initialize(account)
    @account = account
  end

  def getChargesForBuy(stock)
    stock.sum * @account.charges_ratio * 0.01 + @account.comm_charge
  end

  def getChargesForSale(cur_info, stock)
    cur_price = cur_info[3].to_f
    cur_price * stock.buy_quantity * (@account.charges_ratio + @account.tax_ratio) * 0.01  + @account.comm_charge
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

  def getAllProfit(infos)
    profits = {}
    @account.all_stock.each do |stock|
      info = infos[stock.code]
      profits[stock.code] = self.getProfit(info, stock)
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

def fmtPrintProfit(stocks, infos, profits)
  title = sprintf("股票名\t\t买入价\t保本价\t数量\t现价\t盈利\n")
  printf title.colorize(:blue)
  total_profit = 0
  stocks.each do |stock|
    info = infos[stock.code]
    profit =  profits[stock.code]
    test = sprintf("%s\t%.2f\t%.2f\t%d\t%.2f\t%.2f\n", info[0], stock.buy_price, stock.costing, stock.buy_quantity, info[3], profit)
    test = profit >= 0 ? test.colorize( :red ) : test.colorize( :green )
    printf test
    total_profit += profit
  end
  printf "\n总盈利:\t".colorize(:blue)
  total_profit = total_profit > 0 ? total_profit.to_s.colorize(:red) : total_profit.to_s.colorize(:green)
  printf total_profit
  printf "\n"
end


stock_cfg = YAML.load(File.open("stock.yml"))
my_account = Account.buildFromCfg(stock_cfg) #应该在参数更新后重载
current_status = WebInfo.new(stock_cfg["DataSouce"]["url"])
infos = current_status.getStatus(my_account.all_stock)
cal = Caculator.new(my_account)
profits = cal.getAllProfit(infos)
fmtPrintProfit(my_account.all_stock, infos, profits)
