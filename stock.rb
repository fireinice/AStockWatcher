require 'mechanize'
require "iconv"
require "jcode"
$KCODE = 'u'

class Stock
  def initialize(code, market, price, quantity)
    if not code or not market or not price or not quantity
      raise ArgumentError, "Bad data"
    end
    @code = code
    @market = market
    @buy_price = price
    @buy_quantity = quantity
  end

  def Stock.initFromHash(info_hash)
    Stock.new(info_hash["code"], info_hash["market"],
              info_hash["buy_price"], info_hash["buy_quantity"])
  end

  attr_reader :code, :market
end

class Account
  def initialize(charges_ratio, tax_ratio, comm_charge)
    if not charges_ratio or not tax_ratio or not comm_charge
      raise ArgumentError, "Bad data"
    end
    @all_stock = []
    @charges_ratio = charges_ratio
    @tax_ratio = tax_ratio
    @comm_charge = comm_charge
  end

  attr_reader :all_stock

  def addStock(stock)
    @all_stock << stock
  end

  def Account.initChargesFromHash(info_hash)
    Account.new(info_hash["charges_ratio"], info_hash["tax_ratio"],
                info_hash["comm_charge"])
  end

  def Account.buildFromCfg(cfg_yml)
    account = Account.initChargesFromHash(cfg_yml["CommonConfig"])
    basket = cfg_yml["Stocks"]
    basket.each do |stock_info|
      stock = Stock.initFromHash(stock_info)
      account.addStock(stock)
    end
    return account
  end


end


class WebInfo
  @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")
  # http://hq.sinajs.cn/list=sz002238,sz000033
  def initialize(base_url)
    @base_url = base_url
    @fetchAgent = WWW::Mechanize.new { |agent|
      agent.user_agent_alias = 'Linux Mozilla'
      agent.max_history = 0
    }
  end

  def getURL(stockList)
    stock_infos = []
    stockList.each { |stock| stock_infos << stock.market + stock.code  }
    url = @base_url + stock_infos.join(",")
  end

  def fetchData(stockList)
    url = self.getURL(stockList)
    remote_data = @fetchAgent.get_file(url)
    remote_data = @@decoder.iconv(remote_data)
  end

  def getStatus(stockList)
    remote_data = self.fetchData(stockList)
    infos = self.parseData(remote_data)
    p infos
  end

  def parseData(rdata)
    info_hash = {}
    rdata.split("\n").each do |dataLine|
      data_list = dataLine.split("=")
      code = data_list[0][/\d+/]
      info_str = data_list[1].delete("\";")
      infos = info_str.split(",")
      info_hash[code] = infos
    end
    return info_hash
  end

end


stock_cfg = YAML.load(File.open("stock.yml"))
my_account = Account.buildFromCfg(stock_cfg)
current_status = WebInfo.new(stock_cfg["DataSouce"]["url"])
infos = current_status.getStatus(my_account.all_stock)



data.split("\n").each do |info|
  p info
end
p data
data.chomp!.chop!.delete!("\"")
# value_group = data.scan(/\d+(?:\.\d+)?\b/)

open_price = data.shift.to_f    #开盘价
close_price = data.shift.to_f   #收盘价
current_price = data.shift.to_f #报价
high_price = data.shift.to_f    #最高价
buy_charges = buy_price * buy_quantity * charges_ratio * 0.01
p current_price
sale_charges = current_price * buy_quantity * (charges_ratio + tax_ratio) * 0.01
profit = (current_price - buy_price) * buy_quantity - buy_charges - sale_charges - comm_charge
p (profit * 100).round * 0.01
