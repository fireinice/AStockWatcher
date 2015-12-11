# coding: utf-8
require "yaml"
require "logger"

require_relative "gtalk_alert"
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
  attr_writer :direction
end

class AlertManager
  @@interface = SinaTradingDay
  @@yml_filename = "alert.yml"
  @@logger = Logger.new("alert.log")
  @@logger.level = Logger::INFO


  def self.load_alerts(alerts_yml)
    @@yml_filename = alerts_yml
    return YAML.load(File.open(@@yml_filename))
  end

  def dump_alerts()
    File.open( @@yml_filename, 'w' ) do |out|
      YAML.dump(self, out)
    end
  end

  def initialize()
    # alerts = {stock_ref1#direction:[], stock_ref2#direction:[]}
    @alerts = {}
    @freeze_time = {}
    @freeze_gap = 2 * 60 # 2 mins
    @freeze_rose_gap = 30 * 60 # 30 mins
    @freeze_gap_watched = 60 * 60 * 4 # 4 hours
  end

  attr_reader :freeze_gap, :freeze_rose_gap

  def clear_all_dynamic_alerts
    @alerts.values.each do |alerts_list|
      alerts_list.delete_if { |alert| alert.type == AlertType::Dynamic }
    end
  end

  def add_alert(alert)
    return nil if alert.nil?
    alerts = get_alerts(alert)
    alerts << alert
    if alert.direction == AlertDirection::Rose
      alerts.sort!{ |x,y| y.price <=> x.price }
    else
      alerts.sort! { |x,y| x.price <=> y.price }
    end
  end

  def remove_alerts(user, stock)
    get_all_alerts(stock).each do |alerts|
      next if alerts.nil?
      alerts.delete_if { |alert| alert.user == user }
    end
  end

  def update_stocks_alert(user, stock_list)
    infos = @@interface.get_status_batch(stock_list)
    stock_list.each do |stock|
      stock.update_day_trading_info!(infos[stock.code])
      if not stock.buy_quantity.nil? and stock.buy_quantity > 0
        desc = "止损线"
        price_alert = Alert.new(user, stock, stock.buy_price * 0.95, AlertType::Dynamic, desc)
        add_alert(price_alert)
      end
      if stock.class.method_defined?(:gbrc_line) and stock.gbrc_line
        desc = "顾比线"
        gbrc_alert = Alert.new(user, stock, stock.gbrc_line, AlertType::Dynamic, desc)
        add_alert(gbrc_alert)
      end
      if stock.class.method_defined?(:trending_line) and stock.trending_line
        desc = "支撑线"
        trending_alert = Alert.new(user, stock, stock.trending_price,
                                   AlertType::Dynamic, desc)
        desc = "压力线"
        upper_alert = Alert.new(user, stock, stock.pressure_price,
                                AlertType::Dynamic, desc)
        desc = "通道线"
        lower_alert = Alert.new(user, stock, stock.channel_price,
                                AlertType::Dynamic, desc)
        add_alert(trending_alert)
        add_alert(upper_alert)
        add_alert(lower_alert)
      end
    end
  end

  def trigger_alert(stock, alert)
    return if not AStockMarket.is_now_in_trading_time?
    return if alert_freeze?(stock, alert)
    if alert.direction == AlertDirection::Rose
      act = "突破"
    else
      act = "下破"
    end
    content = "#{stock.name}#{act}#{alert.price.round(2)}#{alert.desc},价格#{stock.deal.round(2)},"
    content += "顾比#{stock.gbrc_line.round(2)}," if stock.respond_to?(:gbrc_line) and stock.gbrc_line
    if stock.respond_to?(:trending_line) and stock.trending_line
      content += "支撑#{stock.trending_price},压力#{ (stock.pressure_price)},通道#{(stock.channel_price)},"
    end
    content += Time.now.strftime('%R')

    # SMSBao.send_to(alert.user.phone, content)
    @@logger.info("#{content}")
    GtalkAlert.send_to(alert.user.phone, content)
  end


  def check_alert(stock)
    return if stock.deal.nil? #停牌
    price_triggered = lambda {|alert, stock|
      (stock.deal <=> alert.price) * alert.direction > 0 }
    direction_switcher = lambda { |alert|
      alert.direction = (AlertDirection::Fell == alert.direction)? AlertDirection::Rose : AlertDirection::Fell }
    changed = false

    get_all_alerts(stock).each do |alerts|
      next if alerts.nil? or alerts.empty?
      loop do
        break if not price_triggered.call(alerts[-1], stock)
        changed = true
        alert = alerts.pop
        trigger_alert(stock, alert)
        direction_switcher.call(alert)
        get_alerts(alert).push(alert) if alert.type == AlertType::Dynamic
        break if alerts.empty?
      end
      self.dump_alerts() and return if changed
    end
  end


  def alert_freeze?(stock, alert)
    ref_code = alert.stock.ref_value + alert.user.phone.to_s
    freeze_gap = (stock.buy_quantity.to_f > 0) ? @freeze_gap : @freeze_gap_watched

    return true if alert.desc == "顾比线" and alert.direction == AlertDirection::Rose

    next_alert_time = @freeze_time[ref_code]
    next_alert_time += @freeze_rose_gap if alert.direction == AlertDirection::Rose and not next_alert_time.nil?
    if next_alert_time.nil? or Time.now > next_alert_time
      @freeze_time[ref_code] = Time.now + freeze_gap
      return false
    end
    return true
  end

  def get_all_alerts(stock)
    rose_ref_code = "#{stock.ref_value}##{AlertDirection::Rose}"
    fell_ref_code = "#{stock.ref_value}##{AlertDirection::Fell}"
    return @alerts[rose_ref_code], @alerts[fell_ref_code]
  end

  def get_alerts(alert)
    ref_code = "#{alert.stock.ref_value}##{alert.direction}"
    @alerts[ref_code] = [] if @alerts[ref_code].nil?
    @alerts[ref_code]
  end
  private :alert_freeze?, :get_alerts, :get_all_alerts
end
