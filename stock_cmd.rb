# coding: utf-8
require "optparse"
require "yaml"
require_relative "stock"
require_relative "interface"
require_relative "calculator"
require_relative "gbrc_calculator"
require_relative "trending_calculator"
require_relative "alert"
require_relative "user"

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


  title = sprintf("股票名\t\t买入价\t保本价\t数量\t现价\t盈利\t盈利率\t趋势线\t差率1\t压力线\t差率2\t顾比倒数线\t差率3\n")
  title = tint(title, 1, 0, is_colorful)
  printf title
  total_profit = 0
  stocks.each do |stock|
    info = infos[stock.code]
    profit =  profits[stock.code]
    if info[:deal].to_f < 0.01
      #停牌
      test = sprintf("%s\t-\t-\t-\t-\t-\t-", info[:name])
    elsif
      stock.buy_quantity.nil? or stock.buy_quantity < 1
      #未持股
      test = sprintf("%s\t-\t-\t-\t%s\t-\t-", info[:name], info[:deal])
    else
      test = sprintf("%s\t%.2f\t%.2f\t%d\t%.2f\t%.2f\t%.2f", info[:name], stock.buy_price, stock.costing, stock.buy_quantity, info[:deal], profit[0], profit[1])
      total_profit += profit[0]
      test = tint(test, 2, profit[0]>0, is_colorful)
    end

    gap = TrendingCalculator.get_gap(stock, infos)
    if gap.nil?
      test += "\t-\t-\t-\t-"
    else
      trending_info = sprintf("\t%.2f\t%.2f", gap[0], gap[1])
      trending_info  = tint(trending_info, 2, gap[1] > 0, is_colorful)
      test += trending_info
      trending_info = sprintf("\t%.2f\t%.2f", gap[2], gap[3])
      trending_info  = tint(trending_info, 2, gap[3] > 0, is_colorful)
      test += trending_info
    end

    gbrc_gap = GBRCCalculator.get_gap(stock, infos)
    if gbrc_gap.nil?
      test += "\t-\t-"
    else
      gbrc_info = sprintf("\t%.2f\t%.2f", gbrc_gap[0], gbrc_gap[1])
      gbrc_info  = tint(gbrc_info, 2, gbrc_gap[1] > 0, is_colorful)
      test += gbrc_info
    end

    test += "\n"
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
    @cfg["Stocks"].each do |stock|
      @stocks[stock.ref_value] = stock
    end
    @filename = filename
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

  def updateStockBuyInfo(market, code, price, quatity)
    stockKey = Stock.get_ref_value(market, code)
    if not @stocks.has_key?(stockKey)
      @stocks[stockKey] = Stock.new(code, market)
    end
    @stocks[stockKey].updateBuyInfo(price, quantity)
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
    @stocks[stockKey].updateBuyInfo(price, quantity)
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

if $0 == __FILE__
  cfg_file = CFGController.new("stock.yml")
  watch = false
  plain = false
  stock_cfg = cfg_file.cfg
  my_account = Account.buildFromCfg(stock_cfg) #应该在参数更新后重载
  cal = Caculator.new(my_account)
  opts = nil
  begin
    OptionParser.new do |opts|
      code_parser = lambda {|s| v = []; mkt = s.start_with?('6') ? 'sh' : 'sz'; v << mkt <<  s; }
      opts.banner = "Usage: #$0 [options]"
      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-a", "--add-stock [CODE],[BUY_PRICE],[BUY_QUANTITY]", Array, "Add a stock") do |s|
        v = code_parser.call(s[0])
        v<< s[1].to_f
        v<< s[2].to_i
        cfg_file.addStock(*v)
        exit(0)
      end

      opts.on("-g","--analyze-gbrc [CODE]", String, "analysis a stock with GuBi Revese Count Line") do |s|
        v = code_parser.call(s)
        market = v[0]
        code = v[1]
        stock = cfg_file.getStock(market, code)
        GBRCCalculator.analyze(stock)
        cfg_file.updateStock(stock)
        exit(0)
      end

      opts.on("-n", "--analyze-trending [CODE],[TradingLineStartDate],[TradingLineStartPrice],[TradingLineEndDate],[TradingLineEndPrice],[AmpLineDate],[AmpLinePrice],", Array, "analysis a stock with trading line info") do |s|
        v = code_parser.call(s[0])
        market = v[0]
        code = v[1]
        tradingLineBeginDate = Date.parse(s[1])
        tradingLineBeginPrice = s[2].to_f
        tradingLineEndDate = Date.parse(s[3])
        tradingLineEndPrice = s[4].to_f
        ampLineDate = Date.parse(s[5])
        ampLinePrice = s[6].to_f
        stock = cfg_file.getStock(market, code)
        TrendingCalculator.analyze(
          stock, tradingLineBeginDate, tradingLineBeginPrice,
          tradingLineEndDate, tradingLineEndPrice, ampLineDate, ampLinePrice)
        cfg_file.updateStock(stock)
        exit(0)
      end

      opts.on("-d", "--delete-stock [CODE]", String, "delete a stock") do |s|
        v = code_parser.call(s)
        alert_manager = YAML.load(File.open(cfg_file.cfg["Alert"]["config"]))
        user = User.new(cfg_file.cfg["User"]["phone"])
        alert_manager.remove_alerts(user, cfg_file.getStock(*v))
        cfg_file.delStock(*v)
        exit(0)
      end

      opts.on("-u", "--update-stock-info", "update all stock infos") do
        cfg_file = CFGController.new("stock.yml")
        cfg_file.getAllStocks.each do |stock|
          GBRCCalculator.update_gbrc(stock)
          TrendingCalculator.update_trending(stock)
        end
        cfg_file.updateCFG()
        user = User.new(cfg_file.cfg["User"]["phone"])
        alert_manager = AlertManager.new
        alert_manager.clear_all_dynamic_alerts()
        alert_manager.update_stocks_alert(user, cfg_file.getAllStocks)
        File.open( cfg_file.cfg["Alert"]["config"], 'w' ) do |out|
          YAML.dump(alert_manager , out )
        end
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
        cfg_file.getAllStocks.each.each do |stock|
          puts stock.ref_value
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

  alert_manager = YAML.load(File.open(cfg_file.cfg["Alert"]["config"]))
  all_stocks = cfg_file.getAllStocks
  init = true
  loop do
    begin
      if not AStockMarket.is_now_in_trading_time? and not init
        sleep 5
        next
      end
      infos = SinaTradingDay.get_status_batch(all_stocks)
      all_stocks.each do |stock|
        stock.update_day_trading_info(infos[stock.code])
        alert_manager.check_alert(stock)
      end
      profits = cal.getAllProfit(infos)
      system('clear') if watch
      # fmtPrintProfit(my_account.all_stock, infos, profits, !plain)
      fmtPrintProfit(all_stocks, infos, profits, !plain)
      break if not watch
      sleep 5
      init = false
    rescue Interrupt
      exit(0)
    end
  end
end
