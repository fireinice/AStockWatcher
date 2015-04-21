# coding: utf-8
class StockRecord
  def initialize(date:, open:, close:, high:, low:, vol:, adj_close:)
    @date = Date.parse(date)
    @open = open
    @close = close
    @high = high
    @low = low
    @vol = vol
    @adj_close = adj_close
    @ratio = (@close - @open) / @open
    @adj_ratio = @adj_close / @close
    @adj_open = @adj_ratio * @open
    @adj_high = @adj_ratio * @high
    @adj_low = @adj_ratio * @low
  end

  attr_reader :date, :open, :close, :high, :low, :vol, :ratio,
              :adj_close, :adj_open, :adj_high, :adj_low
end
