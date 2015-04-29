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
  def initialize(user, stock, price, type)
    return nil if not stock.deal and not stock.y_close
    @user = user
    @stock = stock
    @price = price
    cur_price = stock.deal.nil?() ? stock.y_close : stock.deal
    @direction = (cur_price > price ?  AlertDirection::Fell : AlertDirection::Rose)
    @type = type
  end

  attr_reader :user, :stock, :price, :direction, :type
end

class AlertManager
  @@interface = SinaTradingDay

  def initialize()
    # alsert = {stock1:[], stock2:[]}
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
    if alert.direction == AlertDirection::Rose
      @rose_alerts[alert.stock] = [] if @rose_alerts[alert.stock].nil?
      @rose_alerts[alert.stock] << alert
      @rose_alerts[alert.stock].sort!{ |x,y| x.price <=> y.price }
    else
      @fell_alerts[alert.stock] = [] if @fell_alerts[alert.stock].nil?
      @fell_alerts[alert.stock] << alert
      @fell_alerts[alert.stock].sort! { |x,y| y.price <=> x.price }
    end
  end

  def update_stocks_alert(user, stock_list)
    infos = @@interface.get_status_batch(stock_list)
    stock_list.each do |stock|
      stock.update_day_trading_info(infos[stock.code])
      if stock.gbrc_line
        gbrc_alert = Alert.new(user, stock, stock.gbrc_line, AlertType::Dynamic)
        add_alert(gbrc_alert)
      end
      if stock.trending_line
        trending_alert = Alert.new(user, stock, stock.trending_line, AlertType::Dynamic)
        upper_alert = Alert.new(user, stock, stock.trending_line + stock.trending_amp, AlertType::Dynamic)
        lower_alert = Alert.new(user, stock, stock.trending_line - stock.trending_amp, AlertType::Dynamic)
        add_alert(trending_alert)
        add_alert(upper_alert)
        add_alert(lower_alert)
      end
    end
  end

  def trigger_alert(stock, alert)
    return if not AStockMarket.is_now_in_trading_time?
    return if not freeze_time[alert.stock].nil? and freeze_time[alert.stock] > Time.now
    freeze_time[alert.stock] = Time.now
    if alert.direction == AlertDirection::Rose
      act = "突破压力位"
    else
      act = "下破支撑位"
    end
    content = "您的股票[#{stock.name}]#{act}#{'%.02f' % alert.price},当前价格#{stock.price},#{Time.now.strftime('%F %T')}"
    SMSBao.send_to(user.phone, content)
  end

  def check_alert(stock)
    changed = false
    while @rose_alerts.size() > 0
      break if @rose_alerts[0].price > stock.deal
      alert = @rose_alerts.pop
      trigger_alert(alert)
      alert.direction = AlertDirection.Fell
      @fell_alerts.insert(0, alert) if alert.type == AlertType::Dynamic
      changed = true
    end
    return if changed
    while @fell_alerts.size() > 0
      break if @fell_alerts[0].price < stock.deal
      alert = @fell_alerts.pop
      trigger_alert(alert)
      alert.direction = AlertDirection.Rose
      @rose_alerts.insert(0, alert) if alert.type == AlertType::Dynamic
      changed = true
    end
  end
end
