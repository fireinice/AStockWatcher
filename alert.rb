# coding: utf-8
require_relative "smsbao"
require_relative "stock"
module AlertDirection
  Rose = 1
  Fell = -1
end

module AlertType
  Fixed = 1
  Dynamic = 2
end

class Alert
  def self.new(user, stock, price, type, desc)
    (user and stock and (stock.deal or stock.y_close) and price and type) and super
  end

  def initialize(user, stock, price, type, desc)
    @user = user
    @stock = stock
    @price = price
    cur_price = stock.deal.nil?() ? stock.y_close : stock.deal
    @direction = (cur_price > price ?  AlertDirection::Fell : AlertDirection::Rose)
    @type = type
    @desc = desc
  end

  attr_reader :user, :stock, :price, :direction, :type, :desc
end

class AlertManager
  @@interface = SinaTradingDay

  def initialize()
    # alsert = {stock_ref1:[], stock_ref2:[]}
    @rose_alerts = {}
    @fell_alerts = {}
    @freeze_time = {}
    @freeze_gap = 2 * 60 # 2 mins
  end

  def clear_all_dynamic_alerts
    @rose_alerts.values.each do |alerts_list|
      alerts_list.delete_if { |alert| alert.type == AlertType::Dynamic }
    end
    @fell_alerts.values.each do |alerts_list|
      alerts_list.delete_if { |alert| alert.type == AlertType::Dynamic }
    end
  end

  def add_alert(alert)
    ref_code = alert.stock.ref_value
    if alert.direction == AlertDirection::Rose
      @rose_alerts[ref_code] = [] if @rose_alerts[ref_code].nil?
      @rose_alerts[ref_code] << alert
      @rose_alerts[ref_code].sort!{ |x,y| x.price <=> y.price }
    else
      @fell_alerts[ref_code] = [] if @fell_alerts[ref_code].nil?
      @fell_alerts[ref_code] << alert
      @fell_alerts[ref_code].sort! { |x,y| y.price <=> x.price }
    end
  end

  def remove_alerts(user, stock)
    ref_code = stock.ref_value
    @rose_alerts[ref_code].delete_if { |alert| alert.user == user } if @rose_alerts.has_key?(ref_code)
    @fell_alerts[ref_code].delete_if { |alert| alert.user == user } if @fell_alerts.has_key?(ref_code)
  end

  def update_stocks_alert(user, stock_list)
    infos = @@interface.get_status_batch(stock_list)
    stock_list.each do |stock|
      stock.update_day_trading_info!(infos[stock.code])
      if stock.class.method_defined?(:gbrc_line) and stock.gbrc_line
        desc = "顾比倒数线"
        gbrc_alert = Alert.new(user, stock, stock.gbrc_line, AlertType::Dynamic, desc)
        add_alert(gbrc_alert)
      end
      if stock.class.method_defined?(:trending_line) and stock.trending_line
        desc = "支撑线"
        trending_alert = Alert.new(user, stock, stock.trending_line, AlertType::Dynamic, desc)
        desc = "压力线"
        upper_alert = Alert.new(user, stock,
                                stock.trending_line + stock.trending_amp,
                                AlertType::Dynamic, desc)
        desc = "通道线"
        lower_alert = Alert.new(user, stock,
                                stock.trending_line - stock.trending_amp,
                                AlertType::Dynamic, desc)
        add_alert(trending_alert)
        add_alert(upper_alert)
        add_alert(lower_alert)
      end
    end
  end

  def trigger_alert(stock, alert)
    ref_code = stock.ref_value
    return if not AStockMarket.is_now_in_trading_time?
    return if not @freeze_time[ref_code].nil? and @freeze_time[ref_code] > Time.now
    @freeze_time[ref_code] = Time.now + @freeze_gap
    if alert.direction == AlertDirection::Rose
      act = "突破"
    else
      act = "下破"
    end
    content = "您的股票[#{stock.name}]#{act}#{'%.02f' % alert.price}#{alert.desc},当前价格#{stock.price},"
    content += "顾比倒数线#{stock.gbrc_line}," if stock.respond_to?(:gbrc_line) and stock.gbrc_line
    if stock.respond_to?(:trending_line) and stock.trending_line
      content += "支撑线#{stock.trending_line},压力线#{stock.trending_line + stock.trending_amp},通道线#{stock.trending_line - stock.trending_amp},"
    end
    content += "#{Time.now.strftime('%F %T')}"
    SMSBao.send_to(user.phone, content)
  end

  def check_alert(stock)
    ref_code =stock.ref_value
    changed = false
    while not @rose_alerts[ref_code].nil? and @rose_alerts[ref_code].size() > 0
      break if @rose_alerts[ref_code][0].price > stock.deal
      alert = @rose_alerts[ref_code].pop
      trigger_alert(stock, alert)
      alert.direction = AlertDirection.Fell
      @fell_alerts[ref_code].insert(0, alert) if alert.type == AlertType::Dynamic
      changed = true
    end
    return if changed
    while not @fell_alerts[ref_code].nil? and @fell_alerts[ref_code].size() > 0
      break if @fell_alerts[ref_code][0].price < stock.deal
      alert = @fell_alerts[ref_code].pop
      trigger_alert(alert)
      alert.direction = AlertDirection.Rose
      @rose_alerts[ref_code].insert(0, alert) if alert.type == AlertType::Dynamic
      changed = true
    end
  end
end
