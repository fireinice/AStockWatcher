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

  def k_col
    c = [@adj_open, @adj_close]
    (c.min...c.max)
  end

  def is_up?
    @adj_close > @adj_open
  end

  def k_line
    (@adj_low...@adj_high)
  end

  def close=(nclose)
    @close = nclose
    @ratio = (@close-@open)/@open
    @adj_close = @close * @adj_ratio
  end

  def open=(nopen)
    @open = nopen
    @ratio = (@close-@open)/@open
    @adj_open = @open * @adj_ratio
  end

  def high=(nhigh)
    @high = nhigh
    @adj_high = @adj_ratio * @high
  end

  def low=(nlow)
    @low = nlow
    @adj_low = @adj_ratio * @low
  end

end
