# coding: utf-8
require_relative "interface"
#http://blog.csdn.net/ustbhacker/article/details/8365756

class QQTradingDay < WebInterface
  @@base_url = "http://qt.gtimg.cn/q="
  @@inter_name = ["na", "股票名", "代码", "报价", "昨收", "今开", "成交量", "竞卖", "竞买",
                  "买一", "买一量",  "买二", "买二量",  "买三", "买三量",  "买四", "买四量",
                  "买五", "买五量",  "卖一", "卖一量", "卖二", "卖二量",  "卖三", "卖三量",
                  "卖四", "卖四量",  "卖五", "卖五量",  "最近逐笔成交", "时间", "涨跌",
                  "振幅", "最高价", "最低价", "价格/成交量（手）/成交额", "成交量",
                  "成交金额", "换手率", "市盈率", "na", "最高价", "最低价",  "涨跌",
                  "流通市值", "总市值", "市净率", "涨停价", "跌停价"]
  @@inter_name_hk = %w(na, 股票名, 代码, 报价, 昨收, 今开, 成交量, 竞卖, 竞买,
                  买一, 买一量,  买二, 买二量,  买三, 买三量,  买四, 买四量,
                  买五, 买五量,  卖一, 卖一量, 卖二, 卖二量,  卖三, 卖三量,
                  卖四, 卖四量,  卖五, 卖五量,  最近逐笔成交, 时间, 涨跌,
                  涨跌百分比, 最高价, 最低价, 价格/成交量（手）/成交额, 成交量,
                  成交金额, 换手率, 市盈率, na, 最高价, 最低价,  涨跌,
                  流通市值, 总市值, 英文名, 周息率, 涨停价, 跌停价, na)
  @@inter_keys = %i( naa name code deal y_close t_open vol buy_vol sell_vol buy1 buy_vol1 buy2  buy_vol2 buy3 buy_vol3 buy4 buy_vol4 buy5 buy_vol5 sell1 sell_vol1 sell2 sell_vol2 sell3 sell_vol3 sell4 sell_vol4 sell5 sell_vol5 deal_detail datetime change change_rate high low pvt nab turnover turnover_rate pe nac nad nae amp circle_value total_value pb high_limit low_limit )
  @@inter_keys_hk = %i( naa name code deal y_close t_open vol buy_vol sell_vol buy1 buy_vol1 buy2  buy_vol2 buy3 buy_vol3 buy4 buy_vol4 buy5 buy_vol5 sell1 sell_vol1 sell2 sell_vol2 sell3 sell_vol3 sell4 sell_vol4 sell5 sell_vol5 deal_detail datetime change change_rate high low pvt nab turnover turnover_rate pe nac nad nae amp circle_value total_value name_e, wir, high_limit, low_limit, na)
  @@decoder = Iconv.new("UTF-8//IGNORE", "GBK//IGNORE")

  def self.get_url(stock_list)
    stock_infos = []
    stock_list.each do |stock|
      str = ""
      str = "r_" if "hk" == stock.market
      str += stock.market + stock.code
      stock_infos << str
    end
    url = @@base_url + stock_infos.join(",")
  end

  def self.get_status(stock)
    stock_list = [stock]
    infos = get_status_batch(stock_list)
    return infos.values[0]
  end

  def self.get_status_batch(stock_list)
    start = 0
    limit = 30
    infos = {}
    (0..stock_list.size + limit).step(limit) do |n|
      url = get_url(stock_list[start..n])
      remote_data = self.fetch_data(url)
      remote_data = @@decoder.iconv(remote_data)
      next if remote_data.nil?
      infos.merge!(self.parse_data(remote_data))
      start = n + 1
      break if start >= stock_list.size
    end
    infos
  end

  def self.parse_data(rdata)
    info_hash = {}
    rdata.each_line do |data_line|
      ref, info = data_line.split('=')
      market = ref[/sz|sh|hk/]
      code = ref[/\d+/]
      info = info[1..-4]
      infos = info.split('~')
      stock_info = {}
      keys = @@inter_keys
      keys = @@inter_keys_hk if market == "hk"
      raise "data format not as expected" unless keys.size == infos.size
      infos.each_index do |i|
        v = infos[i]
        stock_info[keys[i]] = v
      end
      info_hash[code] = stock_info
    end
    return info_hash
  end
end

if $0 == __FILE__
  require_relative "stock"
  code = "00001"
  market = "hk"
  code = "000001"
  market = "sz"
  Stock.interface = QQTradingDay
  stock = Stock.new(code, market)
  stock.update_trading!()
  puts stock.deal
end
