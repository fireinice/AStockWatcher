# coding: utf-8
require "yaml"

require_relative "trending_calculator"

if $0 == __FILE__
  info_hash = YAML.load(File.open( "trending_scan.yml" ))
  info_array = []
  stocks = []
  info_hash.each do |k,v|
    next if v[0][0][1].points < 15
    item = []
    item << Stock.new(k.code[2,-1])
    item << v[0][0][0]
    item << v[0][0][1]
    info_array << item
    stocks << Stock.new(k.code, k.market)
  end
  info_array.sort!{ |x,y| y[2].points <=> x[2].points }
  stock_infos = SinaTradingDay.get_status_batch(stocks)
  info_array.each do |item|
    stock = item[0]
    t_line = item[1]
    score = item[2]
    stock.update_day_trading_info!(stock_infos[stock.code])
    tg = (stock.y_close - t_line.get_point(-1)) * 100 / t_line.get_point(-1)
    puts "============"
    puts "#{stock.name}, #{stock.code} , #{tg}"
  end
end
