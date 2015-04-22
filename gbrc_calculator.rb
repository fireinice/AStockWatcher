# coding: utf-8
require_relative "stock"
require_relative "interface"
class Stock
  attr_reader :gbrc_base_date, :gbrc_line

  def update_gbrc(base_date, gbrc_line)
    @gbrc_base_date = base_date
    @gbrc_line = gbrc_line
  end
end

class GBRCCalculator
  def self.update_gbrc(stock)
    return if not stock.gbrc_line or not stock.gbrc_base_date
    end_date = Date.today
    end_date = end_date - 1 if not AStockMarket.is_now_after_trading_time?
    begin_date = end_date - 30
    begin_date = stock.gbrc_base_date if stock.gbrc_base_date < begin_date
    stock.extend_history!(begin_date, end_date)
    records = stock.history.get_records_by_range(stock.gbrc_base_date, end_date)
    records.sort! { |a, b| b.adj_close <=> a.adj_close }
    base_record = stock.history.get_record_by_date(stock.gbrc_base_date)
    candidate_rec = records[0]
    return if candidate_rec.adj_close <= base_record.adj_close
    low = self.calc(candidate_rec.date)
    stock.update_gbrc(candidate_rec.date, low)
  end

  def self.get_gap(stock, infos)
    current_price = infos[stock.code][3].to_f
    return nil if stock.gbrc_line.nil? or current_price < 0.01
    gap = current_price - stock.gbrc_line
    gap_ratio = gap * 100 / current_price
    return [stock.gbrc_line, gap_ratio]
  end

  def self.analyze(stock)
    end_date = Date.today
    end_date = end_date - 1 if not AStockMarket.is_now_after_trading_time?
    begin_date = end_date - 45
    success = stock.extend_history!(begin_date, end_date)
    return if not success
    records = stock.history.get_records_by_range(end_date - 15, end_date)
    records.sort! { |a, b| b.adj_close <=> a.adj_close }
    candidate_rec = records[0]
  end

  def self.calc(base_date)
    gap = 15
    cur_gap = gap
    reverse_cnt = 2
    found = false
    loop do
      stock.extend_history!(end_date - gap, end_date)
      records = stock.history.get_records_by_range(end_date - gap, end_date)
      records.sort! { |a, b| b.date <=> a.date }
      low = records[0].adj_low
      records.each do |record|
        if record.adj_low < low
          reverse_cnt -= 1
          low = record.adj_low
          return low if reverse_cnt == 0
        end
      end
      end_date -= gap
    end
  end
end


if $0 == __FILE__
  require_relative "stock_cmd"
  cfg_file = CFGController.new("stock.yml")
  cfg_file.getAllStocks.each { |stock| GBRCCalculator.update_gbrc(stock) }
  cfg_file.updateCFG()
end
