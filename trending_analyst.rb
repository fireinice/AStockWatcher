# coding: utf-8
require "yaml"
require_relative "trending_calculator"
require_relative "qq_interface"
require_relative "ctxalgo_interface"

def sort_by_points(infos)
  line_infos = {}
  s_lines = []
  infos.each do |ref, v|
    support_lines = v[0][:candis]
    pressure_lines = v[1]
    support_lines.each do |s|
      line_infos[s] = ref
      s_lines << s
    end
  end
  s_lines.sort!{ |x,y| y.score.points <=> x.score.points }
  ret_info = {}
  s_lines.each do |l|
    next if ret_info.has_key?(l)
    ret_info[line_infos[l]] = infos[line_infos[l]]
  end
  ret_info
end


if $0 == __FILE__
  infos = YAML.load(File.open("trending_scan.yml"))
  Stock.interface = QQTradingDay
  stocks = {}

  infos.each_key do |ref|
    stocks[ref] = Stock.new(ref[2..-1])
  end

  stock_infos = QQTradingDay.get_status_batch(stocks.values)

  infos = sort_by_points(infos)

  infos.each do |ref, value|
    support_lines = value[0]
    pressure_lines = value[1]
    stock = stocks[ref]
    stock.update_day_trading_info!(stock_infos[stock.ref_value])
    next if stock.deal.nil? # skip stop trading stock
    # skip if line above price now more than 5% or below than 5%
    accept_range =Range.new(stock.deal * 0.95, stock.deal * 1.05)
    s_lines = []
    p_lines = []
    support_lines[:candis].each.with_index do |line, i|
      next if not accept_range.cover?(line.get_point(-1))
      s_lines << line
      p_lines << pressure_lines[i]
    end
    next if s_lines.empty?
    puts "=========="
    puts "#{stock.name}, PE:#{stock.pe}, PB:#{stock.pb}"
    # puts StockPlate.get_status(stock)
    CalcTrendingHelper.print_info(stock, support_lines[:score])
    CalcTrendingHelper.print_info(stock, support_lines[:points])
    for i in (0..s_lines.size()) do
      s_line = s_lines[i]
      p_line = p_lines[i]
      #p_line could be nil if pressure line too close to support line
      next if p_line.nil?
      CalcTrendingHelper.print_info(stock, s_line, p_line)
    end
  end

end
