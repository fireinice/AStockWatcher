#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "optparse"
require "yaml"
require 'terminal-table/import'
# require 'terminal-table'
require_relative "stock"
require_relative "interface"
require_relative "calculator"
require_relative "gbrc_calculator"
require_relative "trending_calculator"
require_relative "alert"
require_relative "user"
require_relative "ctxalgo_interface"

def htmlTint(str, type, *bool_ref)
  # type: 1=>"title",2=>"profit"
  # bool_ref contains: is_gain(?), is_colorful
  color = nil
  if bool_ref[-1]
    case type
    when 1
      color = 'blue'
    when 2
      bool_ref[-2] ? color = 'red' :
              color = 'green'
    end
  end
  str = "<span style='color:#{color}'>  " + str.to_s + "  </span>"
  return str
end

def tint(str, type, *bool_ref)
  # type: 1=>"title",2=>"profit"
  # bool_ref contains: is_gain(?), is_colorful
  if bool_ref[-1]
    case type
    when 1
      str =str.colorize(:light_cyan)
    when 2
      str = bool_ref[-2] ? str.to_s.colorize( :light_red ) :
              str.to_s.colorize( :light_green )
    end
  end
  return str
end

def fmtPrintProfit2(stocks, infos, profits, is_colorful)
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

  heading = %w(股票名 买入价 保本价 数量 现价 盈利 盈利率)
  heading += %w(趋势线 差率1 压力线 差率2) if Stock.method_defined?(:trending_line)
  heading += %w(顾比倒数线 差率3) if Stock.method_defined?(:gbrc_line)
  heading.map!{ |item| tint(item, 1, 0, is_colorful) }

  rows = []
  total_profit = 0
  stocks.each do |stock|
    row = []
    profit = profits[stock.code]
    row << stock.name
    if stock.deal.nil? or stock.deal < 0.01
      row += ['-'] * 6
    elsif stock.buy_quantity.nil? or stock.buy_quantity < 1
      row += ['-'] * 3
      row += [stock.deal]
      row += ['-'] * 2
    else
      deal_info = [stock.buy_price, stock.costing, stock.buy_quantity, stock.deal]
      deal_info.map!{ |item| item = item.to_f.round(2).to_s }
      row += deal_info
      profit_info = profit.map do |item|
        item = item.round(2)
        tint(item, 2, profit[1]>0, is_colorful)
      end
      row += profit_info
      total_profit += profit[0]
    end

    gap = TrendingCalculator.get_gap(stock, infos)
    if gap.nil? and stock.respond_to?(:trending_line)
      row += ['-'] * 4
    else
      gap_info = gap[0,4].map.with_index do |item, i|
        item = item.round(2)
        cond = ( i < 2 ?  gap[1]> 0 : gap[3]> 0 )
        tint(item, 2, cond , is_colorful)
      end
      row += gap_info
    end

    gbrc_gap = GBRCCalculator.get_gap(stock, infos)
    if gbrc_gap.nil? and stock.respond_to?(:gbrc_line)
      row += ['-'] * 2
    else
      gap_info = gbrc_gap.map do |item|
        item = item.round(2)
        tint(item, 2, gbrc_gap[1] > 0, is_colorful)
      end
      row += gap_info
    end
    rows << row
  end
  table = Terminal::Table.new :headings => heading, :rows => rows
  system('clear')
  puts table

  total_title = "总盈利:\t"
  total_title = tint(total_title, 1, 0, is_colorful)
  printf total_title
  is_gain = total_profit > 0
  total_profit = sprintf("%.2f", total_profit)
  total_profit = tint(total_profit, 2, is_gain, is_colorful)
  puts total_profit
end

def htmlPrintProfit2(stocks, infos, profits, is_colorful)
  begin
    require "rubygems"
    require "html/table"
    include HTML
  rescue LoadError
    begin
      require "html/table"
      include HTML
    rescue LoadError
      p "The output require html-table library support, \
please install it manully or with gems. "
      exit 1
    end
  end

  table = Table.new do
    border      1
  end

  thead = Table::Head.create
  tbody = Table::Body.new
  tfoot = Table::Foot.create

  thead.push Table::Row.new{ |r|
    heading = %w(股票名 买入价 保本价 数量 现价 盈利 盈利率)
    heading += %w(趋势线 差率1 压力线 差率2) if Stock.method_defined?(:trending_line)
    heading += %w(顾比倒数线 差率3) if Stock.method_defined?(:gbrc_line)
    heading.map!{ |item| htmlTint(item, 1, 0, true) }
    r.content = heading
    r.align = "center"
  }

  rows = []
  total_profit = 0
  stocks.each do |stock|
    tr = Table::Row.new
    row = []
    profit = profits[stock.code]
    row << stock.name
    if stock.deal.nil? or stock.deal < 0.01
      row += ['-'] * 6
    elsif stock.buy_quantity.nil? or stock.buy_quantity < 1
      row += ['-'] * 3
      row += [stock.deal]
      row += ['-'] * 2
    else
      deal_info = [stock.buy_price, stock.costing, stock.buy_quantity, stock.deal]
      deal_info.map!{ |item| item = item.to_f.round(2).to_s }
      row += deal_info
      profit_info = profit.map do |item|
        item = item.round(2)
        htmlTint(item, 2, profit[1]>0, is_colorful)
      end
      row += profit_info
      total_profit += profit[0]
    end

    gap = TrendingCalculator.get_gap(stock, infos)
    if gap.nil? and stock.respond_to?(:trending_line)
      row += ['-'] * 4
    else
      gap_info = gap[0,4].map.with_index do |item, i|
        item = item.round(2)
        cond = ( i < 2 ?  gap[1]> 0 : gap[3]> 0 )
        htmlTint(item, 2, cond , is_colorful)
      end
      row += gap_info
    end

    gbrc_gap = GBRCCalculator.get_gap(stock, infos)
    if gbrc_gap.nil? and stock.respond_to?(:gbrc_line)
      row += ['-'] * 2
    else
      gap_info = gbrc_gap.map do |item|
        item = item.round(2)
        htmlTint(item, 2, gbrc_gap[1] > 0, is_colorful)
      end
      row += gap_info
    end
    tr.content = row
    tr.align = "center"
    table.push tr
  end


  # total_title = "总盈利:\t"
  # total_title = tint(total_title, 1, 0, is_colorful)
  # printf total_title
  # is_gain = total_profit > 0
  # total_profit = sprintf("%.2f", total_profit)
  # total_profit = tint(total_profit, 2, is_gain, is_colorful)
  # puts total_profit


  table.push thead
  File.open("test.html", "w+") do |aFile|
    aFile.write("<html><meta http-equiv='Content-Type' content='text/html; charset=UTF-8''><head><title>股票</title></head><body>")
    aFile.write(table.html)
    aFile.write("</body></html>")
  end
  # heading = %w(股票名 买入价 保本价 数量 现价 盈利 盈利率)
  # heading += %w(趋势线 差率1 压力线 差率2) if Stock.method_defined?(:trending_line)
  # heading += %w(顾比倒数线 差率3) if Stock.method_defined?(:gbrc_line)
  # heading.map!{ |item| tint(item, 1, 0, is_colorful) }

  # rows = []
  # total_profit = 0
  # stocks.each do |stock|
  #   row = []
  #   profit = profits[stock.code]
  #   row << stock.name
  #   if stock.deal.nil? or stock.deal < 0.01
  #     row += ['-'] * 6
  #   elsif stock.buy_quantity.nil? or stock.buy_quantity < 1
  #     row += ['-'] * 3
  #     row += [stock.deal]
  #     row += ['-'] * 2
  #   else
  #     deal_info = [stock.buy_price, stock.costing, stock.buy_quantity, stock.deal]
  #     deal_info.map!{ |item| item = item.to_f.round(2).to_s }
  #     row += deal_info
  #     profit_info = profit.map do |item|
  #       item = item.round(2)
  #       tint(item, 2, profit[1]>0, is_colorful)
  #     end
  #     row += profit_info
  #     total_profit += profit[0]
  #   end

  #   gap = TrendingCalculator.get_gap(stock, infos)
  #   if gap.nil? and stock.respond_to?(:trending_line)
  #     row += ['-'] * 4
  #   else
  #     gap_info = gap[0,4].map.with_index do |item, i|
  #       item = item.round(2)
  #       cond = ( i < 2 ?  gap[1]> 0 : gap[3]> 0 )
  #       tint(item, 2, cond , is_colorful)
  #     end
  #     row += gap_info
  #   end

  #   gbrc_gap = GBRCCalculator.get_gap(stock, infos)
  #   if gbrc_gap.nil? and stock.respond_to?(:gbrc_line)
  #     row += ['-'] * 2
  #   else
  #     gap_info = gbrc_gap.map do |item|
  #       item = item.round(2)
  #       tint(item, 2, gbrc_gap[1] > 0, is_colorful)
  #     end
  #     row += gap_info
  #   end
  #   rows << row
  # end
  # table = Terminal::Table.new :headings => heading, :rows => rows
  # system('clear')
  # puts table

  # total_title = "总盈利:\t"
  # total_title = tint(total_title, 1, 0, is_colorful)
  # printf total_title
  # is_gain = total_profit > 0
  # total_profit = sprintf("%.2f", total_profit)
  # total_profit = tint(total_profit, 2, is_gain, is_colorful)
  # puts total_profit
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

      opts.on("-b", "--buy-stock [CODE],[BUY_PRICE],[BUY_QUANTITY]", Array, "Add a stock") do |s|
        code, market = Stock.parse_code(s[0])
        #stock = cfg_file.getStock(market, code)
        v = []
        v<< s[1].to_f
        v<< s[2].to_i
        cfg_file.updateStockBuyInfo(market, code, *v)
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
        GBRCCalculator.analyze(stock)
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
        all_stocks = cfg_file.getAllStocks
        infos = SinaTradingDay.get_status_batch(all_stocks)
        all_stocks.each do |stock|
          stock.update_day_trading_info!(infos[stock.code])
          puts "#{stock.code} #{stock.name}"
        end
        exit(0)
      end

      opts.on("-s", "--scan",  "scan all stocks") do
        info_hash = {}
        stocks = StockList.get_status()
        stocks.each_key.with_index do |ref, i|
          market = ref[0..1]
          code = ref[2..-1]
          stock = Stock.new(code, market)
          # TrendingCalculator.calc_trending(stock)
          infos = TrendingCalculator.calc_trending(stock)
          next if infos.nil?
          info_hash[stock.ref_value] = infos
        end
        File.open( "trending_scan.yml", 'w' ) do |out|
          YAML.dump(info_hash , out )
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

  alert_manager = AlertManager.load_alerts(
    File.open(cfg_file.cfg["Alert"]["config"]))
  all_stocks = cfg_file.getAllStocks
  init = true
  File.open('pid', 'w') { |file| file.write("#{$$}") }
  loop do
    begin
      if not AStockMarket.is_now_in_trading_time? and not init
        sleep 5
        next
      end
      infos = SinaTradingDay.get_status_batch(all_stocks)
      all_stocks.each do |stock|
        stock.update_day_trading_info!(infos[stock.code])
        alert_manager.check_alert(stock)
      end
      profits = cal.getAllProfit(infos)
      # system('clear') if watch
      # fmtPrintProfit(my_account.all_stock, infos, profits, !plain)
      fmtPrintProfit2(all_stocks, infos, profits, !plain)
      htmlPrintProfit2(all_stocks, infos, profits, !plain)
      break if not watch
      sleep 5
      init = false
    rescue Interrupt
      exit(0)
    end
  end
end
