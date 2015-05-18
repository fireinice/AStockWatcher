# coding: utf-8
require_relative "../ctxalgo_interface"
require_relative "../stock"

describe  do
  it "should return interface url" do
    stock = Stock.new("600438")
    stock_list = [stock]
    expect(StockPlate.get_url(stock_list, Date.today)).to eq("http://ctxalgo.com/api/plate_of_stocks/sh600438?date=2015-05-17")
    print StockPlate.get_status(stock)
  end
end
