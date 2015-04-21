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
    records = stock.history.get_records_by_range(begin_date, candidate_rec.date)
    records.sort! { |a, b| b.date <=> a.date }
    reverse_cnt = 2
    low = records[0].adj_low
    records.each do |record|
      if record.low < low
        reverse_cnt = reverse_cnt - 1
        low = record.low
      end
      break if reverse_cnt == 0
    end
    stock.update_gbrc(candidate_rec.date, low)
  end

  def self.getGap(stock, infos)
    if stock.gbrc_line.nil?
      return nil
    end
    curPrice = infos[stock.code][3].to_f
    tDiff = curPrice - stock.gbrc_line
    gapRatio = tDiff * 100 / curPrice
    return [tDiff, gapRatio]
  end

  def self.calc(stock)
    if stock.hasHistory?
      history = stock.history
    else
      endDate = Date.today.prev_day
      begDate = endDate - 30
      records = YahooHistory.getStatus(stock, begDate, endDate)
      history = StockHistory.new(stock, records)
    end
  end
end


if $0 == __FILE__
  require_relative "stock_cmd"
  cfg_file = CFGController.new("stock.yml")
  cfg_file.getAllStocks.each { |stock| GBRCCalculator.update_gbrc(stock) }
end
