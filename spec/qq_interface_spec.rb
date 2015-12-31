# coding: utf-8
require_relative "../qq_interface"
require_relative "../stock"

describe  do
  before :each do
    @stock_list = []
    @stock_list << Stock.new("600000")
    @stock_list << Stock.new("000001")
  end

  it "should return interface url" do
    expect(QQTradingDay.get_url(@stock_list)).to eq("http://qt.gtimg.cn/q=sh600000,sz000001")
  end

  it "should get stock info" do
    url = QQTradingDay.get_url(@stock_list)
    remote_data = QQTradingDay.fetch_data(url)
    expect(remote_data).not_to be_nil
  end

  it "should parse stock info" do
    expect(QQTradingDay.get_status_batch(@stock_list)).not_to be_nil
  end

  it "should be the same of the data from sina" do
    s = Stock.new("600000")
    qq = QQTradingDay.get_status(s)
    sina = SinaTradingDay.get_status(s)
    qq.each do |k,v|
      #以下几个有量级的差别！
      next if k.to_s.include?("vol")
      next if :turnover == k
      expect(v).to eq sina[k] if sina.has_key? k
    end
  end

  it "should be the same of the hk data from sina" do
    s = Stock.new("600000")
    qq = QQTradingDay.get_status(s)
    sina = SinaTradingDay.get_status(s)
    qq.each do |k,v|
      #以下几个有量级的差别！
      next if k.to_s.include?("vol")
      next if :turnover == k
      expect(v).to eq sina[k] if sina.has_key? k
    end
  end

end
