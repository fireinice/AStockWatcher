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
$KCODE = 'u'
require "net/http"
require "uri"
require "iconv"
require "jcode"
require "optparse"
require "yaml"

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

  def ref_value
    @market + @code
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

def tint(str, type, *bool_ref)
  # type: 1=>"title",2=>"profit"
  # bool_ref contains: is_gain(?), is_colorful
  if bool_ref[-1]
    case type
    when 1
      str =str.colorize(:light_cyan)
    when 2
      str = bool_ref[-2] ? str.colorize( :light_red ) :
        str.colorize( :light_green )
    end
  end
  return str
end

def fmtPrintProfit(stocks, infos, profits, is_colorful)
  if is_colorful
    begin
      require "rubygems"
      require "colorize"
    rescue LoadError
      begin
        require "colorize"
      rescue LoadError
        p "The output require colorize library support, \
please install it manully or with gems. \
Or you could use argument -p to disable the colorful print effect."
        exit 1
      end
    end
  end

  title = sprintf("股票名\t\t买入价\t保本价\t数量\t现价\t盈利\t盈利率\n")
  title = tint(title, 1, 0, is_colorful)
  printf title
  total_profit = 0
  stocks.each do |stock|
    info = infos[stock.code]
    profit =  profits[stock.code]
    if info[3].to_f < 0.01
      #停牌
      test = sprintf("%s\t-\t-\t-\t-\t-\t-\n", info[0])
    else
      test = sprintf("%s\t%.2f\t%.2f\t%d\t%.2f\t%.2f\t%.2f\n", info[0], stock.buy_price, stock.costing, stock.buy_quantity, info[3], profit[0], profit[1])
      test = tint(test, 2, profit[0]>0, is_colorful)
      total_profit += profit[0]
    end
    print test
  end
  total_title = "\n总盈利:\t"
  total_title = tint(total_title, 1, 0, is_colorful)
  printf total_title
  is_gain = total_profit > 0
  total_profit = sprintf("%.2f", total_profit)
  total_profit = tint(total_profit, 2, is_gain, is_colorful)
  puts total_profit
end

class CFGController
  def initialize(filename)
    @cfg = YAML.load(File.open(filename))
    @filename = filename
  end
  attr_reader :cfg

  def updateCFG()
    File.open( @filename, 'w' ) do |out|
      YAML.dump(@cfg , out )
    end
  end

  def addStock(market, code, price, quantity)
    stock = {}
    stock["market"] = market
    stock["code"] = code
    stock["buy_price"] = price
    stock["buy_quantity"] = quantity
    @cfg["Stocks"] << stock
    # should check stock if invalid here
    self.updateCFG()
  end

  def delStock(market, code)
    stocks = @cfg["Stocks"]
    to_delete = nil
    stocks.delete_if {|stock| code == stock["code"] and market == stock["market"] }
    self.updateCFG()
  end

end

cfg_file = CFGController.new("stock.yml")
watch = false
plain = false
stock_cfg = cfg_file.cfg
my_account = Account.buildFromCfg(stock_cfg) #应该在参数更新后重载
current_status = WebInfo.new(stock_cfg["DataSouce"]["url"])
cal = Caculator.new(my_account)
opts = nil
begin
  OptionParser.new do |opts|
    code_parser = lambda {|s| v = []; v << s[0,2] <<  s[2..-1]; }
    opts.banner = "Usage: #$0 [options]"
    opts.separator ""
    opts.separator "Specific options:"

    opts.on("-a", "--add-stock [sh|sz_CODE],[BUY_PRICE],[BUY_QUANTITY]", Array, "Add a stock") do |s|
      v = code_parser.call(s[0])
      v<< s[1].to_f
      v<< s[2].to_i
      cfg_file.addStock(*v)
      exit(0)
    end

    opts.on("-d", "--delete-stock [sh|sz_CODE]", String, "delete a stock") do |s|
      v = code_parser.call(s)
      cfg_file.delStock(*v)
      exit(0)
    end

    opts.on("-l", "--list", "list all stock") do
      my_account.all_stock.each do |stock|
        p stock.ref_value
      end
      exit(0)
    end

    opts.on("-w", "--[no-]watch",  "open watch mode") do |s|
      watch = s
    end

    opts.on("-p", "--plain",  "open watch mode") do |s|
      plain = s
    end

    opts.on_tail("-h", "--help", "Show help message") do
      puts opts
      exit
    end
  end.parse!
rescue OptionParser::InvalidOption
  p opts.to_s
  exit(0)
end

loop do
  begin
    infos = current_status.getStatus(my_account.all_stock)
    profits = cal.getAllProfit(infos)
    system('clear') if watch
    fmtPrintProfit(my_account.all_stock, infos, profits, !plain)
    break if not watch
    sleep 5
  rescue Interrupt
    exit(0)
  end
end
