# coding: utf-8
require_relative "stock"
require_relative "interface"
class Stock
  attr_reader :trending_base_date, :trending_line, :day_price_diff, :trending_amp
  def update_trending_info(trending_base_date, trending_line,
                           day_price_diff, trending_amp)
    @trending_base_date = trending_base_date
    @trending_line = trending_line
    @day_price_diff = day_price_diff
    @trending_amp = trending_amp
  end
end

class IndexLine
  def initialize(index, base, diff)
    @index = index
    @base = base
    @diff = diff
  end

  def self.init_with_points(index1, point1, index2, point2)
    diff = (point2 - point1) / (index2 - index1)
    line = IndexLine.new(index1, point1, diff)
    line.v_index = index2
    line.v_point = point2
    line
  end

  attr_reader :index, :base, :diff
  attr_accessor :v_index, :v_point

  def get_diff(index)
    @diff * (index - @index)
  end

  def get_point(index)
    @base + get_diff(index)
  end
end


class CalcTrendingHelper
  class Score
    def initialize
      @segs = 0
      @points = 0
      @belows = 0
      @score = 0
    end

    attr_accessor :segs, :points, :score, :belows

    def plus!(other)
      if not other.nil?
        self.score += other.score
        self.segs += other.segs
        self.points += other.points
        self.belows += other.belows
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

    def add_seg_score!(date)
      @score += 1 * self.date_score(date)
      @segs += 1
      self
    end
  end

  class DaySegments
    def initialize(record, trading_days)
      @record = record
      @point_delta = record.adj_low * 0.001
      @days_gap = trading_days
      @date = record.date
      info = []
      info << record.adj_open
      info << record.adj_close
      info << record.adj_high
      info << record.adj_low
      info.sort!
      @low1, @low2, @high1, @high2 = info
      @point_segs = []
      info.each { |point| @point_segs << Range.new(point-@point_delta, point+@point_delta) }
      @segs = []
      @segs << Range.new(@low1, @low2)
      @segs << Range.new(@high1, @high2)
    end

    attr_reader :date, :low1, :low2, :high1, :high2, :days_gap, :point_delta

    def index
      # days_gap is a reverse count so we reverse again here
      -@days_gap
    end

    def score(line)
      point = line.get_point(self.index)
      s = Score.new()
      s.minus_below_score!(@date) if @record.adj_close < point

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
      @calc_day_infos << DaySegments.new(record, total_trading_days - index)
    end
  end

  def self.calc_trending_lines(seg1, seg2, type)
    segs = [seg1, seg2]
    segs.sort!{ |x,y| x.date <=> y.date }
    prev, back = segs
    days = prev.days_gap - back.days_gap
    lines = []
    case type
    when :high
      lines << IndexLine.init_with_points(
        prev.index, prev.high1, back.index, back.high1)
      lines << IndexLine.init_with_points(
        prev.index, prev.high1, back.index, back.high2)
      lines << IndexLine.init_with_points(
        prev.index, prev.high2, back.index, back.high1)
      lines << IndexLine.init_with_points(
        prev.index, prev.high2, back.index, back.high2)
    when :low
      lines << IndexLine.init_with_points(
        prev.index, prev.low1, back.index, back.low1)
      lines << IndexLine.init_with_points(
        prev.index, prev.low1, back.index, back.low2)
      lines << IndexLine.init_with_points(
        prev.index, prev.low2, back.index, back.low1)
      lines << IndexLine.init_with_points(
        prev.index, prev.low2, back.index, back.low2)
    end
    lines.uniq
  end
  def calc_pressure_lines(support_lines)
    lines = []
    support_lines.each do |line, score|
      high_score = 0
      high_line = nil
      #{point:[seg1, seg2], point2[seg3]....}
      point_hash = {}
      points = []
      pt_tmp = []
      point_delta = line.base * 0.002
      @calc_day_infos.each do |day_segs|
        diff = line.get_diff(day_segs.index)
        day_points = []
        day_points << day_segs.high1 - diff
        day_points << day_segs.high2 - diff
        # puts "date:#{day_segs.date}, diff:#{diff}, day_points:#{day_points}, high1:#{day_segs.high1}, high2:#{day_segs.high2}"
        day_points.each do |pt|
          next if pt < line.base * 1.05
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
        high_line, high_score =
                   IndexLine.new(seg_value.index, pt + line.get_diff(seg_value.index), line.diff),score if score >= high_score
      end
      lines << [high_line, high_score]
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


  def calc_support_lines(lines, stock)
    scores = []
    base_price = stock.history.get_last_record.adj_close
    # skip if line above price now more than 5% or below than 5%
    accept_range =Range.new(base_price * 0.95, base_price * 1.05)

    lines.each do |line|
      next if not accept_range.cover?(line.get_point(-1))
      score = @calc_day_infos.reduce(Score.new) { |memo, info| memo.plus!(info.score(line)) }
      # skip if the line across only 2 points and less than 5 segs
      next if score.points < 10 and score.segs < 15
      scores << [line, score]
    end
    scores.sort!{ |x,y| y[1].score <=> x[1].score}
    # scores[0,10].each do |score|
    #   puts "========"
    #   puts score[1].score
    #   puts score[1].segs
    #   puts score[1].points
    #   puts score[0].base
    #   puts score[0].v_point
    #   puts stock.history.get_record_by_reverse_gap_days(score[0].index).date
    #   puts stock.history.get_record_by_reverse_gap_days(score[0].v_index).date
    #   puts score[0].index
    #   puts score[0].v_index
    # end

    return scores
  end

  def calc(stock)
    high_increment_lines = []
    low_increment_lines = []
    @calc_day_infos.each.with_index do |prev, i|
      @calc_day_infos[(i+1)..-1].each do |back|
        # we only calc increment by now
        # CalcTrendingHelper.calc_trending_lines(prev, back, :high).each {
        #   |line| high_increment_lines << line if line.diff > 0}
        CalcTrendingHelper.calc_trending_lines(prev, back, :low).each {
          |line| low_increment_lines << line if line.diff > 0}
      end
    end

    support_lines = calc_support_lines(low_increment_lines, stock)
    calc_end =  support_lines.size > 10 ? 10 : support_lines.size
    calc_range = (0...calc_end)

    pressure_lines = calc_pressure_lines(support_lines[calc_range])

    stock.update_trading!()

    puts "============"
    puts "#{stock.name}, #{stock.code}"

    for i in calc_range
      s_line = support_lines[i][0]
      sscore = support_lines[i][1]
      sd1 = stock.history.get_record_by_reverse_gap_days(s_line.index).date
      sl1 = s_line.base
      sd2 = stock.history.get_record_by_reverse_gap_days(s_line.v_index).date
      sl2 = s_line.v_point
      puts "支撑线: #{sd1}, #{sl1}, #{sd2}. #{sl2}"
      tg = (stock.history.get_last_record.adj_close - s_line.get_point(-1)) * 100/ s_line.get_point(-1)

      p_line = pressure_lines[i][0]
      pd = stock.history.get_record_by_reverse_gap_days(p_line.index).date
      pl = p_line.base
      pg = (p_line.get_point(s_line.index) - s_line.base) * 100 / s_line.base
      puts "压力线: #{pd}, #{pl}"
      puts "日差:#{s_line.diff.round(2)} , 回归差：#{tg.round(2)}%, 压力差: #{pg.round(2)}%"
      puts "支撑分数: #{sscore.score.round(2)}, 支撑点数: #{sscore.points}, 支撑线数：#{sscore.segs}, 跌破比例：#{sscore.belows}/#{@calc_day_infos.size}"
      # puts s_line.index, s_line.base, s_line.diff, s_line.v_index, s_line.v_point
      puts "--------"
    end
    return support_lines[calc_range], pressure_lines[calc_range]
  end
end

class TrendingCalculator
  def self.calc_trending(stock)
    end_date = Date.today
    begin_date = end_date - 30 * 6 # 6 months
    extended = stock.extend_history!(begin_date, end_date)
    return if not extended
    helper = CalcTrendingHelper.new(stock)
    trending_hash = {}
    helper.calc(stock)
    #[[point_range1, point_range2,
  end


  def self.update_trending(stock)
    return if not stock.trending_base_date or not stock.trending_line or
      not stock.day_price_diff or not stock.trending_amp
    end_date = Date.today
    begin_date = stock.trending_base_date
    return if begin_date == end_date and not AStockMarket.is_now_after_trading_time?
    extended = stock.extend_history!(begin_date, end_date)
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
                               stock.day_price_diff, stock.trending_amp)
  end

  def self.analyze(stock, start_date, start_price,
                   end_date, end_price, amp_date, amp_price)
    dates = [start_date, end_date, amp_date]
    dates.sort!
    begin_date = dates[0]
    stock.extend_history!(start_date, end_date)
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
    gap = current_price - stock.trending_line
    gap_ratio = gap * 100 / current_price
    if gap < 0
      amp = stock.trending_line - stock.trending_amp
      amp_type = 'l'
    else
      amp = stock.trending_line + stock.trending_amp
      amp_type = 'u'
    end
    amp_ratio = (current_price - amp) * 100 / current_price
    return [stock.trending_line, gap_ratio, amp, amp_ratio, amp_type]
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
  cfg_file.getAllStocks.each { |stock| TrendingCalculator.update_trending(stock) }
  cfg_file.updateCFG()
end
