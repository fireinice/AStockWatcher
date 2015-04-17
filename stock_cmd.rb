# coding: utf-8
require "optparse"
require "yaml"
require_relative "stock"
require_relative "interface"
require_relative "calculator"

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
    @stocks = {}
    @cfg["Stocks"].each do |stockInfo|
      stock = Stock.initFromHash(stockInfo)
      @stocks[stock.ref_value] = stock
    end
    @filename = filename
  end
  attr_reader :cfg

  def updateCFG()
    File.open( @filename, 'w' ) do |out|
      YAML.dump(@cfg , out )
    end
  end

  def updateStockTrendingInfo(market, code, begDate, dayPriceDiff, amp)
    stockKey = Stock.get_ref_value(market, code)
    if not @stocks.has_key?(stockKey)
      @stocks[stockKey] = Stock.new(code, market)
    end
    @stocks[stockKey].updateTrendingInfo(begDate, dayPriceDiff, amp)
    @cfg["Stocks"] = []
    @stocks.each { |stock| @cfg["Stocks"] << stock.to_hash }
    self.updateCFG()
  end

  def updateStockBuyInfo(market, code, price, quatity)
    stockKey = Stock.get_ref_value(market, code)
    if not @stocks.has_key?(stockKey)
      @stocks[stockKey] = Stock.new(code, market)
    end
    @stocks[stockKey].updateBuyInfo(price, quantity)
    @cfg["Stocks"] = []
    @stocks.each { |stock| @cfg["Stocks"] << stock.to_hash }
    self.updateCFG()
  end

  def addStock(market, code)
    stock = {}
    stock["market"] = market
    stock["code"] = code
    @cfg["Stocks"] << stock
    # should check stock if invalid here
    self.updateCFG()
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

  def setCharges(charge_name, charge_money)
    charges_config = @cfg["CommonConfig"]
    if not charges_config.has_key?(charge_name)
      return charges_config.keys
    end
    charges_config[charge_name] = charge_money.to_f
    self.updateCFG()
  end
end

if $0 == __FILE__
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

      opts.on("-n", "--analysis-stock [sh|sz_CODE],[TradingLineStartDate],[TradingLineStartPrice],[TradingLineEndDate],[TradingLineEndPrice],[AmpLineDate],[AmpLinePrice],", Array, "analysis a stock with trading line info") do |s|
        v = code_parser.call(s[0])
        market = v[0]
        code = v[1]
        tradingLineBeginDate = Date.parse(s[1])
        tradingLineBeginPrice = s[2].to_f
        tradingLineEndDate = Date.parse(s[3])
        tradingLineEndPrice = s[4].to_f
        ampLineEndDate = Date.parse(s[5])
        ampLineEndPrice = s[6].to_f
        cfg_file.updateTrendingInfo()
        exit(0)
      end

      opts.on("-d", "--delete-stock [sh|sz_CODE]", String, "delete a stock") do |s|
        v = code_parser.call(s)
        cfg_file.delStock(*v)
        exit(0)
      end

      opts.on("-c", "--config [charges_ratio|tax_ratio|other_charge=charge]") do |money|
        data = money.split("=")
        # charges_list =  ["charges_ratio", "tax_ratio", "other_charge"]
        ret = cfg_file.setCharges(data[0], data[1])
        if ret.class.to_s == "Array"
          all_charges = ret.join("|")
          puts "the charge name should be in #{all_charges}"
          exit(1)
        end
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
end
