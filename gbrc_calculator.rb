# coding: utf-8
require_relative "stock"
require_relative "interface"
class Stock
  attr_reader :gbrc_base_date, :gbrc_line, :gbrc_buy_line, :gbrc_buy_base_date

  def update_gbrc(base_date, gbrc_line)
    @gbrc_base_date = base_date
    @gbrc_line = gbrc_line
  end

  def update_gbrc_buy_line(base_date,gbrc_line)
    @gbrc_buy_base_date = base_date
    @gbrc_buy_line = gbrc_line
  end
end

class GBRCCalculator
  def self.update_gbrc(stock)
    return if not stock.gbrc_line or not stock.gbrc_base_date
    end_date = Date.today
    end_date = end_date - 1 if not AStockMarket.is_now_after_trading_time?
    begin_date = end_date - 30
    begin_date = stock.gbrc_base_date if stock.gbrc_base_date < begin_date
    extended = stock.extend_history!(begin_date, end_date)
    return if !extended
    records = stock.history.get_records_by_range(stock.gbrc_base_date, end_date)
    return if not records
    records.sort! { |a, b| b.adj_close <=> a.adj_close }
    base_record = stock.history.get_record_by_date(stock.gbrc_base_date)
    candidate_rec = records[0]
    return if candidate_rec.adj_close <= base_record.adj_close
    low = self.calc(stock, candidate_rec.date)
    stock.update_gbrc(candidate_rec.date, low) if low > stock.gbrc_line
  end

  def self.get_gap(stock, infos)
    current_price = infos[stock.code][:deal].to_f
    return nil if stock.gbrc_line.nil? or current_price < 0.01
    gap = current_price - stock.gbrc_line
    gap_ratio = gap * 100 / current_price
    return [stock.gbrc_line, gap_ratio]
  end

  def self.analyze_new(stock, start=:high, init_gap=30, step=14)
    end_date = Date.today
    end_date = end_date - 1 if not AStockMarket.is_now_before_trading_time?
    case start
    when :high
      calc_new(stock, end_date, start, 14)
    when :low
      calc_new(stock, end_date, start, 14)
    when :both
      calc_new(stock, end_date, :high, 14)
      calc_new(stock, end_date, :low, 14)
    end
  end

  def self.calc_new(stock, end_date, start=:high, init_gap=30)
    begin_date = end_date - init_gap
    success = stock.extend_history!(begin_date, end_date)
    return 0 if success.nil?
    sort_prop = :adj_close
    search_prop = :adj_low
    search_prop = :adj_high if :low == start
    records = stock.history.get_records_by_range(begin_date, end_date)
    records.sort! { |a, b| b.adj_close <=> a.adj_close }
    peak = (start == :high ? records[0] : records[-1])
    loop_cnt = 0
    max_loop_cnt = 10
    range_date = begin_date
    loop do
      loop_cnt += 1
      reverse_cnt = 2
      return 0 if loop_cnt > max_loop_cnt
      sort_recs = stock.history.get_records_by_range(begin_date, peak.date)
      sort_recs.sort! { |a, b| b.date <=> a.date }
      base_date = sort_recs[0].date
      line = sort_recs[0].send(search_prop)
      sort_recs.each do |record|
        if record.k_col.cover?(line)
          reverse_cnt -= 1
          line = record.send(search_prop)
          return line,base_date if reverse_cnt == 0
        end
      end
      if range_date < begin_date
        range_date -= 30
        stock.extend_history!(range_date, end_date)
      end
    end
  end

  def self.analyze(stock, start=:high)
    begin_date = end_date - 45
    success = stock.extend_history!(begin_date, end_date)
    return if not success
    records = stock.history.get_records_by_range(end_date - 30, end_date)
    records.sort! { |a, b| b.adj_close <=> a.adj_close }
    if :high == start or :both == start
      candidate_rec = records[0]
      low = calc(stock, candidate_rec.date)
      stock.update_gbrc(candidate_rec.date, low)
    end
    if :low == start or :both == start
      candidate_rec = records[-1]
      low = calc(stock, candidate_rec.date, :low)
      stock.update_gbrc_buy_line(candidate_rec.date, low)
    end
  end

  def self.calc(stock, base_date, start=:high)
    gap = 15
    cur_gap = gap
    reverse_cnt = 2
    found = false
    end_date = base_date
    loop_cnt = 1
    max_loop_cnt = 10
    loop do
      stock.extend_history!(end_date - gap * loop_cnt, end_date)
      records = stock.history.get_records_by_range(
        end_date - gap * loop_cnt, end_date)
      loop_cnt += 1
      return 0 if loop_cnt > max_loop_cnt
      next if records.empty? or records.nil?
      records.sort! { |a, b| b.date <=> a.date }
      low = records[0].adj_low
      high = records[0].adj_high
      records.each do |record|
        if :high == start
          if record.adj_low < low
            reverse_cnt -= 1
            low = record.adj_low
            return low if reverse_cnt == 0
          end
        end
        if :low == start
          if record.adj_high > high
            reverse_cnt -= 1
            high = record.adj_high
            return high if reverse_cnt == 0
          end
        end
      end
    end
  end
end


if $0 == __FILE__
  require_relative "stock_cmd"
  cfg_file = CFGController.new("stock.yml")
  cfg_file.getAllStocks.each { |stock| GBRCCalculator.update_gbrc(stock) }
  cfg_file.updateCFG()
end
