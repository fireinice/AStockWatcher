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

TRADING_STR = 'var hq_str_sz002238="天威视讯,23.10,23.09,22.20,23.15,22.20,22.20,22.21,5947829,134462400.84,81780,22.20,200,22.19,15800,22.18,10000,22.17,2200,22.16,28000,22.21,44764,22.22,1100,22.23,5100,22.24,18872,22.25,2015-12-31,15:05:56,00";'

TRADING_STR_HK = 'var hq_str_rt_hk00001="CKH HOLDINGS,长和,104.900,104.700,104.900,104.300,104.600,-0.100,-0.096,104.400,104.800,117206299.900,1120902,3.004,10.185,174.900,97.500,2015/12/31,12:05:02";'

describe SinaTradingDay do
  it "should return current deal price" do
    decoder = Iconv.new("GBK//IGNORE", "UTF-8//IGNORE")
    gbk_str = decoder.iconv(TRADING_STR)
    stock = Stock.new("600438")
    allow(SinaTradingDay).to receive(:fetch_data).and_return(gbk_str)
    info = SinaTradingDay.get_status(stock)
    expect(info[:deal]).to eq("22.20")
  end

  it "should return current hk deal price" do
    decoder = Iconv.new("GBK//IGNORE", "UTF-8//IGNORE")
    gbk_str = decoder.iconv(TRADING_STR_HK)
    stock = Stock.new("600438")
    allow(SinaTradingDay).to receive(:fetch_data).and_return(gbk_str)
    info = SinaTradingDay.get_status(stock)
    expect(info[:deal]).to eq("104.600")
  end
end
