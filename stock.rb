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

  attr_reader :code, :market, :buy_price, :buy_quantity

  def Stock.initFromHash(info_hash)
    Stock.new(info_hash["code"], info_hash["market"],
              info_hash["buy_price"], info_hash["buy_quantity"])
  end

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

  attr_reader :all_stock, :charges_ratio, :tax_ratio, :comm_charge

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

class Caculator
  def initialize(account)
    @account = account
  end

  def getChargesForBuy(stock)
    stock.buy_price * stock.buy_quantity * @account.charges_ratio * 0.01 + @account.comm_charge
  end

  def getChargesForSale(cur_info, stock)
    cur_price = cur_info[3].to_f
    cur_price * stock.buy_quantity * (@account.charges_ratio + @account.tax_ratio) * 0.01 + @account.comm_charge
  end

  def getGrossProfit(cur_info, stock)
    cur_price = cur_info[3].to_f
    (cur_price - stock.buy_price) * stock.buy_quantity
  end

  def getProfit(cur_info, stock)
    g_profit = self.getGrossProfit(cur_info, stock) #毛利润
    buy_charges = self.getChargesForBuy(stock)
    sale_charges = self.getChargesForSale(cur_info, stock)
    profit = g_profit - buy_charges - sale_charges
  end

  def getAllProfit(infos)
    profits = {}
    @account.all_stock.each do |stock|
      info = infos[stock.code]
      profits[stock.code] = self.getProfit(info, stock)
    end
    p profits
    return profits
  end

end


stock_cfg = YAML.load(File.open("stock.yml"))
my_account = Account.buildFromCfg(stock_cfg)
current_status = WebInfo.new(stock_cfg["DataSouce"]["url"])
infos = current_status.getStatus(my_account.all_stock)
cal = Caculator.new(my_account)
cal.getAllProfit(infos)


# p (profit * 100).round * 0.01
