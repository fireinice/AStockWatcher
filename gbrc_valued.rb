#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
require "optparse"
require_relative "cfg_controller"
require_relative "gbrc_calculator"
require_relative "user"
require_relative "alert"

if $0 == __FILE__
  global_cfg = CFGController.new("stock.yml")
  cfg_file = CFGController.new("valued_stock.yml")
  opts = nil
  begin
    OptionParser.new do |opts|
      opts.banner = "Usage: #$0 [options]"
      opts.separator ""
      opts.separator "Specific options:"
      opts.on("-a", "--add-stock [CODE]", String, "Add a stock") do |s|
        v = Stock.parse_code(s)
        market = v[0]
        code = v[1]
        stock = cfg_file.getStock(market, code)
        GBRCCalculator.analyze(stock, :both,7)
        cfg_file.updateStock(stock)
        exit(0)
      end
      opts.on("-u", "--update", "update all stock infos") do 
        cfg_file.getAllStocks.each do |stock|
          GBRCCalculator.analyze(stock, :both, 7)
          cfg_file.updateStock(stock)
          exit(0)
        end
      end
    end.parse!
  end
  alert_manager = AlertManager.new("valued_alert.yml")
  user = User.new(global_cfg.cfg["User"]["phone"])
  alert_manager.update_stocks_alert(user, cfg_file.getAllStocks)
  all_stocks = cfg_file.getAllStocks
  all_stocks.each do |stock|
    alert_manager.check_alert(stock)
  end
end
