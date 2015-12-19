# coding: utf-8
require 'date'
require 'set'
require_relative "stock"
require_relative "interface"
require_relative "trending_calculator_exp"

class MongoInterface
  require "mongo"
  Mongo::Logger.logger.level = ::Logger::FATAL
  @@client = Mongo::Client.new('mongodb://127.0.0.1:27017/scrapy')

  def self.get_status(code)
    code = code[2..-1] if code.start_with?('s')
    ret_list = []
    @@client[:stocks].find(:code => code).each do |item|
      ret_list << item
    end
    raise "more than one code matched" unless 1 == ret_list.length
    ret_list[0]
  end
end

class Stock
  attr_reader :trending_base_date, :trending_line, :day_price_diff, :trending_amp
  attr_accessor :trending_type, :industry, :concept, :qq_sectors

  def update_trending_info(trending_base_date, trending_line,
                           day_price_diff, trending_amp, trending_type=nil)
    @trending_base_date = trending_base_date
    @trending_line = trending_line
    @day_price_diff = day_price_diff
    @trending_amp = trending_amp
    @trending_type = trending_type unless trending_type.nil?
  end

  def get_real_price(input, accuracy=2)
    input = Math.exp(input) if :exp == @trending_type
    input.round(accuracy)
  end

  def trending_price
    get_real_price(@trending_line)
  end

  def channel_price
    get_real_price(@trending_line - @trending_amp)
  end

  def pressure_price
    get_real_price(@trending_line + @trending_amp)
  end
end

class IndexLine
  @@sh = StockHistory.new(Stock.new('600000'), [])
  @@today = Date.today

  def initialize(index, base, diff)
    @index = index
    @base = base
    @diff = diff
    @update_date = @@today
  end

  def self.init_with_points(index1, point1, date1, index2, point2,date2)
    diff = (point2 - point1) / (index2 - index1)
    line = IndexLine.new(index1, point1, diff)
    line.index_date = date1
    line.v_index = index2
    line.v_point = point2
    line.v_date = date2
    line.type = :linear
    line
  end

  def ==(o)
    (o.get_point(@index) - @base).round(10) == 0 and (@diff - o.diff).round(10) == 0
  end

  attr_reader :index, :base, :diff, :update_date
  attr_accessor :v_index, :v_point, :index_date, :v_date, :score, :type

  def up_to_today!(stock)
    @@sh = StockHistory.new(stock, []) if stock.ref_value != @@sh.stock.ref_value
    return if @update_date >= @@today
    days = @@sh.getTradingDays(@update_date, @@today)
    return nil if days.nil?
    @v_index = @v_index - days + 1 if not @v_index.nil?
    @index = @index - days + 1 if not @index.nil?
    @update_date = @@today
  end

  def get_diff(index)
    @diff * (index - @index)
  end

  def get_point(index)
    @base + get_diff(index)
  end

  def last_point()
    get_point(-1)
  end
end


class CalcTrendingHelper
  class Score
    def initialize
      @segs = 0
      @points = 0
      # fixme below应该只算支撑线后部分的
      @belows = 0
      @score = 0
      @too_high_days = 0
    end

    attr_reader :too_high_days
    attr_accessor :segs, :points, :score, :belows, :calc_base_num

    def plus!(other)
      if not other.nil?
        @score += other.score
        @segs += other.segs
        @points += other.points
        @belows += other.belows
        @too_high_days += other.too_high_days
      end
      self
    end

    def <=>(other)
      self.score <=> other.score
    end

    def +(other)
      s = Score.new
      if not other.nil?
        s.score = self.score + other.score
        s.segs = self.segs + other.segs
        s.points = self.points + s.points
        s.belows = self.belows + s.belows
      end
      s
    end

    def date_score(date)
      days = (Date.today - date)
      months = days / 30
      #1, 2-3, 4-5, 6
      1.0 / ((months + 1).div(2) + 1)
    end

    def add_point_score!(date)
      @score += 2 * self.date_score(date)
      @points += 1
      self
    end

    def minus_below_score!(date)
      @score -= 0.5 * self.date_score(date)
      @belows += 1
      self
    end

    def minus_too_high_day!(date)
      #删除之前出现的过高的点
      @too_high_days += 1
    end

    def add_seg_score!(date)
      @score += 1 * self.date_score(date)
      @segs += 1
      self
    end
  end

  class DaySegments
    def initialize(record, trading_days, type)
      @record = record
      @trending_type = type
      if :exp == @trending_type
        @point_delta = Math.log(1+0.0002)
        accuracy = 8
      else
        @point_delta = record.adj_low * 0.0002
        accuracy = 2
      end
      @days_gap = trading_days
      @date = record.date
      info = []
      info << record.adj_open.round(accuracy)
      info << record.adj_close.round(accuracy)
      info << record.adj_high.round(accuracy)
      info << record.adj_low.round(accuracy)
      info.sort!
      @low1, @low2, @high1, @high2 = info
      @segs = []
      @segs << Range.new(@low1, @low2)
      @segs << Range.new(@high1, @high2)

      @point_segs = []
      info.uniq!
      info.each { |point| @point_segs << Range.new(point-@point_delta, point+@point_delta) }
    end

    attr_reader :date, :low1, :low2, :high1, :high2, :days_gap, :point_delta, :record

    def index
      # days_gap is a reverse count so we reverse again here
      -@days_gap
    end

    def score(line)
      point = line.get_point(self.index)
      s = Score.new()
      s.minus_below_score!(@date) if @record.adj_close < point
      too_high_point = point * 1.2
      if :exp == @trending_type
        too_high_point = point + Math.log(1.2)
      end
      s.minus_too_high_day!(@date) if @record.adj_close > too_high_point

      @point_segs.each do |seg|
        return s.add_point_score!(@date) if seg.cover?(point)
      end

      @segs.each do |seg|
        return s.add_seg_score!(@date) if seg.cover?(point)
      end

      return s
    end
  end

  def initialize(stock)
    @calc_day_infos = []
    total_trading_days = stock.history.records.size
    stock.history.records.each.with_index do |record, index|
      @calc_day_infos << DaySegments.new(record, total_trading_days - index, stock.trending_type)
    end
  end

  def calc_trending_lines(seg1, seg2, type)
    segs = [seg1, seg2]
    segs.sort!{ |x,y| x.date <=> y.date }
    prev, back = segs
    days = prev.days_gap - back.days_gap
    lines = []
    prev_points = []
    back_points = []
    case type
    when :high
      prev_points << prev.high1
      prev_points << prev.high2 if 0 != (prev.high1 - prev.high2).round(10)
      back_points << back.high1
      back_points << back.high2 if 0 != (back.high1 - back.high2).round(10)
    when :low
      prev_points << prev.low1
      prev_points << prev.low2 if 0 != (prev.low1 - prev.low2).round(10)
      back_points << back.low1
      back_points << back.low2 if 0 != (back.low1 - back.low2).round(10)
    end
    prev_points.each do |p|
      back_points.each do |b|
        line = IndexLine.init_with_points(
          prev.index, p, prev.date, back.index, b, back.date)
        line.type = :exp
        #已经小于统计误差，失去意义
        next if line.diff < 0.001
        lines << line
      end
    end
    return lines
  end

  def calc_pressure_lines(support_lines, type)
    lines = []
    support_lines.each do |line|
      # score = line.score
      high_score = 0
      high_line = nil
      #{point:[seg1, seg2], point2[seg3]....}
      point_hash = {}
      points = []
      pt_tmp = []
      # point_delta = line.base * 0.002
      if :exp == type
        point_delta = Math.log(1+0.002)
        accept_range = Range.new(line.base + Math.log(1.05), line.base + Math.log(1.12))
      else
        point_delta = line.base * 0.002
        accept_range = Range.new(line.base * 1.05, line.base * 1.12)
      end
      @calc_day_infos.each do |day_segs|
        diff = line.get_diff(day_segs.index)
        day_points = []
        day_points << day_segs.high1 - diff
        day_points << day_segs.high2 - diff
        # puts "date:#{day_segs.date}, diff:#{diff}, day_points:#{day_points}, high1:#{day_segs.high1}, high2:#{day_segs.high2}"
        day_points.each do |pt|
          # only search between %5 to 12%
          next if not accept_range.cover?(pt)
          point_hash[pt] = [] if point_hash[pt].nil?
          point_hash[pt] << day_segs
          pt_tmp << pt
          points << pt
        end
        points.sort!
        pt_tmp.sort!
      end
      base_score = 0
      points.reverse_each do |pt|
        while pt_tmp[-1] > pt + point_delta
          tpt = pt_tmp.pop
          base_score -= point_hash[tpt].size * 0.5
        end
        score = base_score
        # score = 0
        pt_tmp.reverse_each do |tpt|
          break if tpt < pt - point_delta
          score += point_hash[tpt].size
        end
        # puts pt
        seg_value = point_hash[pt][0]
        if score >= high_score
          high_line, high_score =
                     IndexLine.new(seg_value.index, pt + line.get_diff(seg_value.index), line.diff),score
          high_line.index_date = seg_value.date
        end
      end
      if not high_line.nil?
        high_line.score = high_score
        lines << high_line
      end
    end

    # high_score = Score.new
    # support_lines.each do |line, score|
    #   @calc_day_infos.each do |day_segs|
    #     candis = []
    #     candis << IndexLine.new(day_segs.index, day_segs.high1, line.diff)
    #     candis << IndexLine.new(day_segs.index, day_segs.high2, line.diff)
    #     candis.each do |candi|
    #       # skip if pressure line gap is less than 5%
    #       next if candi.get_point(line.index) <= line.base * 1.05
    #       score = @calc_day_infos.reduce(Score.new) { |memo, info| memo.plus!(info.score(line)) }
    #       # puts score.class
    #       high_line, high_score = candi, score if score.score > high_score.score
    #       lines << [high_line, high_score]
    #     end
    #   end
    # end
    return lines
  end


  def calc_support_lines(candi_lines, stock)
    lines = {}
    candis = []
    high_points_line = nil
    high_points = 0
    high_score_line = nil
    high_score = 0
    base_price = stock.history.get_last_record.adj_close
    # skip if line above price now more than 5% or below than 15%
    if :exp == stock.trending_type
      accept_range =Range.new(base_price + Math.log(0.95), base_price + Math.log(1.15))
    else
      accept_range =Range.new(base_price * 0.95, base_price * 1.15)
    end
    candi_lines.each do |line|
      score = @calc_day_infos.reduce(Score.new) { |memo, info| memo.plus!(info.score(line)) }
      score.calc_base_num = @calc_day_infos.size - score.too_high_days
      line.score = score
      if score.points > high_points
        high_points_line = line
        high_points = score.points
      end
      if score.score > high_score
        high_score_line = line
        high_score = score.score
      end
      next if not accept_range.cover?(line.last_point)
      # skip if the line across less than 10 points and less than 15 segs
      next if score.points < 10 and score.segs < 15
      # skip if too many days is below the support line
      next if score.belows > score.calc_base_num / 3
      candis << line
      # break
    end

    candis.sort!{ |x,y| y.score.score <=> x.score.score}

    # 截断到10个
    calc_end =  candis.size > 10 ? 10 : candis.size
    calc_range = (0...calc_end)
    candis = candis[calc_range]
    lines[:points] = high_points_line
    lines[:score] = high_score_line if not high_score_line == high_points_line
    lines[:candis] = candis
    return nil if candis.empty?

    return lines
  end

  def self.print_line_info(stock, s_line, p_line=nil)
    return if s_line.nil?
    base_price = stock.deal.nil? ? stock.y_close : stock.deal
    return if base_price.nil?
    puts "停牌" if stock.deal.nil?
    sscore = s_line.score
    sd1 = s_line.index_date
    sd2 = s_line.v_date
    sl1 = s_line.base.round(2)
    sl2 = s_line.v_point.round(2)

    print "支撑压力线: #{stock.code},#{sd1},#{sl1},#{sd2},#{sl2}"
    #p_line could be nil if pressure line too close to support line
    if not p_line.nil?
      pd = p_line.index_date
      pl = p_line.base.round(2)
      print ",#{pd},#{pl}"
      pg = (stock.get_real_price(p_line.get_point(s_line.index), 5) - stock.get_real_price(s_line.base, 5)) * 100 / stock.get_real_price(s_line.base, 5)
    end

    day_diff = (stock.get_real_price(s_line.diff, 5) - 1) * stock.get_real_price(s_line.last_point, 5)
    if :exp == stock.trending_type
      puts ",exp"
      day_diff = day_diff.round(5)
    else
      puts",line"
      day_diff = s_line.diff.round(2)
    end
    day_diff_ratio = day_diff * 100 / stock.get_real_price(s_line.last_point,5)
    day_diff_ratio = day_diff_ratio.round(5)
    tg = (base_price - stock.get_real_price(s_line.last_point,5)) * 100/ stock.get_real_price(s_line.last_point,5)

    print "日差:#{day_diff}, 日涨幅:#{day_diff_ratio}, 回归差：#{tg.round(2)}%"
    if not p_line.nil?
      puts ",压力差: #{pg.round(2)}%"
    else
      puts ""
    end
    puts "支撑分数: #{sscore.score.round(2)}, 支撑点数: #{sscore.points}, 支撑线数：#{sscore.segs}, 跌破比例：#{sscore.belows}/#{sscore.calc_base_num}"
    # puts s_line.index, s_line.base, s_line.diff, s_line.v_index, s_line.v_point
    puts "--------"
  end

  def get_least_diff(day_info)
    lows = [day_info.low1, day_info.low2]
    #we can calc the most diff and least diff to limit the search lines
    #如果diff很大，对前面的结果是有利的，但是不利于后面的情况，反之亦然
  end

  def self.print_stock_lines_info(stock, support_lines, pressure_lines)
    puts "============"
    puts "#{stock.name}, #{stock.code}"
    for sector in %w(@industry @concept @qq_sectors)
      if stock.instance_variable_defined?(sector)
        items = stock.instance_variable_get(sector)
        next if items.nil?
        for item in items
          puts "#{sector[1..-1]}: #{item}"
        end
      end
    end
    candis = support_lines[:candis]

    return nil, nil if candis.empty?
    CalcTrendingHelper.print_line_info(stock, support_lines[:score])
    CalcTrendingHelper.print_line_info(stock, support_lines[:points])
    for i in (0..candis.size()) do
      s_line = candis[i]
      p_line = pressure_lines[i]
      #p_line could be nil if pressure line too close to support line
      next if p_line.nil?
      CalcTrendingHelper.print_line_info(stock, s_line, p_line)
    end
    puts Time.now
  end

  def calc(stock)
    high_increment_lines = []
    low_increment_lines = []
    @calc_day_infos.each.with_index do |prev, i|
      @calc_day_infos[(i+1)..-1].each do |back|
        # we only calc increment by now
        # CalcTrendingHelper.calc_trending_lines(prev, back, :high).each {
        #   |line| high_increment_lines << line if line.diff > 0}
        self.calc_trending_lines(prev, back, :low).each {
          |line| low_increment_lines << line if line.diff > 0}
      end
    end

    support_lines = calc_support_lines(low_increment_lines, stock)
    return nil if support_lines.nil?

    pressure_lines = calc_pressure_lines(support_lines[:candis], stock.trending_type)
    stock.update_trading!()
    stocks.qq_sectors = MongoInterface.get_status(stock.code)['qq_sector']
    CalcTrendingHelper.print_stock_lines_info(stock, support_lines, pressure_lines)
    return support_lines, pressure_lines
  end
end


class TrendingCalculator
  def self.adapter_exists?()
    begin
      klass = Module.const_get("TrendingCalculatorAdapter")
      return klass.is_a?(Class)
    rescue NameError
      return false
    end
  end


  def self.generate_history!(stock, begin_date, end_date)
    extended = stock.extend_history!(begin_date, end_date)
    return false if not extended
    if TrendingCalculator.adapter_exists?
      TrendingCalculatorAdapter.to_inner!(stock)
    end
    stock
  end

  def self.calc_trending(stock)
    end_date = Date.today
    begin_date = end_date - 30 * 6 # 6 months
    extended = TrendingCalculator.generate_history!(stock, begin_date, end_date)
    # extended = stock.extend_history!(begin_date, end_date)
    return if not extended
    helper = CalcTrendingHelper.new(stock)
    helper.calc(stock)
  end


  def self.update_trending(stock)
    return if not stock.trending_base_date or not stock.trending_line or
      not stock.day_price_diff or not stock.trending_amp
    end_date = Date.today
    begin_date = stock.trending_base_date
    return if begin_date >= end_date
    return if begin_date == end_date and not AStockMarket.is_now_after_trading_time?
    extended = TrendingCalculator.generate_history!(stock, begin_date, end_date)
    return if not extended
    gap_trading_days = stock.history.getTradingDays(begin_date, end_date)
    # end_date include then we should minus 1 for gap
    gap_trading_days -= 1 if stock.history.get_last_record.date >= end_date
    # after trading time, we caculator next day
    if AStockMarket.is_now_after_trading_time?
      end_date += 1
      gap_trading_days += 1
    end
    # if base date is not a trending day, we need to minus it
    gap_trading_days -= 1 if not stock.history.is_trading_day?(stock.trending_base_date)
    return if gap_trading_days <= 0
    trending_line = stock.trending_line + stock.day_price_diff * gap_trading_days
    stock.update_trending_info(end_date, trending_line,
                               stock.day_price_diff,
                               stock.trending_amp)
  end

  def self.analyze(stock, start_date, start_price,
                   end_date, end_price, amp_date, amp_price, trending_type)
    dates = [start_date, end_date, amp_date]
    dates.sort!
    extended = TrendingCalculator.generate_history!(stock, dates[0], dates[-1])
    calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp =
                                                 calc(
                                                   stock,
                                                   start_date, start_price,
                                                   end_date, end_price,
                                                   amp_date, amp_price)
    if not calcBeginDate.nil?
      stock.update_trending_info(calcBeginDate, calcBeginPrice, dayPriceDiff, trendingAmp)
    else
      puts "date error"
    end
  end


  def self.get_gap(stock, infos)
    current_price = infos[stock.code][:deal].to_f
    return nil if not stock.trending_base_date or current_price < 0.01
    end_date = Date.today
    end_date = end_date + 1 if AStockMarket.is_now_after_trading_time?
    update_trending(stock) if end_date > stock.trending_base_date
    trending_price = stock.trending_price
    gap = current_price - trending_price
    gap_ratio = gap * 100 / current_price
    if gap < 0
      amp = stock.trending_line - stock.trending_amp
      amp_type = 'l'
    else
      amp = stock.trending_line + stock.trending_amp
      amp_type = 'u'
    end
    amp = stock.get_real_price(amp, 5)
    amp_ratio = (current_price - amp) * 100 / current_price
    return [trending_price, gap_ratio, amp, amp_ratio, amp_type]
  end

  def self.calc(stock, begLineDate, begLinePrice, endLineDate, endLinePrice, highLineDate, highLinePrice)
    priceDiff = endLinePrice - begLinePrice
    tDays = stock.history.getTradingDays(begLineDate, endLineDate)
    if tDays < 1
      return nil
    end
    tDiff = priceDiff / (tDays - 1)
    begDiffDate = endLineDate
    begDiffPrice = endLinePrice
    case begLineDate <=> highLineDate
    when -1
      tDays = stock.history.getTradingDays(begLineDate, highLineDate)
    when 1
      tDays = -stock.history.getTradingDays(highLineDate, begLineDate)
    when 0
      tDays = 1
    end
    highLineDatePrice = begLinePrice + tDiff * (tDays - 1)
    tAmp = highLinePrice - highLineDatePrice
    return [begDiffDate, begDiffPrice, tDiff, tAmp]
  end
end

if $0 == __FILE__
  require_relative "stock_cmd"
  cfg_file = CFGController.new("stock.yml")
  TrendingCalculator.calc_trending(Stock.new("600256"))
  # cfg_file.getAllStocks.each { |stock| TrendingCalculator.update_trending(stock) }
  # cfg_file.updateCFG()
end
