# coding: utf-8
require_relative "../interface"
require_relative "../stock"

describe YahooHistory do
  it "should return interface url" do
    stock = Stock.new("600438")
    end_date = Date.parse("150511")
    begin_date = end_date - 6 * 30
    expect(YahooHistory.get_url(stock, begin_date, end_date)).to eq("http://table.finance.yahoo.com/table.csv?a=10&b=12&c=2014&d=4&e=11&f=2015&s=600438.ss")
  end
end
