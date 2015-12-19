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
  ret_infos = {}
  s_lines.each do |l|
    next if ret_infos.has_key?(l)
    ret_infos[line_infos[l]] = infos[line_infos[l]]
  end
  ret_infos
end

def formatted_print(stocks, infos)
  infos.each do |ref, value|
    support_lines = value[0]
    pressure_lines = value[1]
    stock = stocks[ref]
    CalcTrendingHelper.print_stock_lines_info(
      stock, support_lines, pressure_lines)
  end
end

def filter_by_deal_diff(stocks, infos, accept_ratio)
  accept_range =Range.new(0, accept_ratio)
  ret_infos = {}
  infos.each do |ref, value|
    support_lines = value[0]
    pressure_lines = value[1]
    stock = stocks[ref]
    break if stock.nil?
    next if stock.deal.nil? # skip stop trading stock
    stock.trending_type = :exp
    s_lines = []
    p_lines = []
    support_lines[:candis].each.with_index do |line, i|
      # skip if line above price now more than 5% or below than 5%
      # diff = (stock.deal-line.get_point(-1)).abs
      line.up_to_today!(stock)
      diff = (stock.deal - stock.get_real_price(line.last_point)).abs
      next if not accept_range.cover?(diff/stock.deal)
      pressure_lines[i].up_to_today!(stock) if not pressure_lines[i].nil?
      s_lines << line
      p_lines << pressure_lines[i]
    end
    next if s_lines.empty?
    ret_infos[ref] = infos[ref]
    ret_infos[ref][0][:candis] = s_lines
    ret_infos[ref][1] = p_lines
  end
  ret_infos
end

if $0 == __FILE__
  infos = YAML.load(File.open("trending_scan.yml"))
  Stock.interface = QQTradingDay
  stocks = {}

  infos.each_key do |ref|
    stocks[ref] = Stock.new(ref[2..-1])
    result = MongoInterface.get_status(ref[2..-1])
    # stocks[ref].industry = result["industry"]
    # stocks[ref].concept = result["concept"]
    stocks[ref].qq_sectors = result["qq_sector"]
  end

  stock_infos = QQTradingDay.get_status_batch(stocks.values)

  stocks.each_value { |stock| stock.update_day_trading_info!(stock_infos[stock.ref_value])}

  infos = filter_by_deal_diff(stocks, infos, 0.05)
  infos = sort_by_points(infos)

  formatted_print(stocks, infos)
end
