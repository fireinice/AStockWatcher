# coding: utf-8
require_relative "support/factory_girl"
require_relative "../alert"

describe "stock alert" do
  before :each do
    @user = FactoryGirl.build(:user)
    @stock = FactoryGirl.build(:stock_no_deal)
    base_price = 12
    @rose_price = base_price + 0.5
    @fell_price = base_price - 0.5
    @trigger_rose = @rose_price + 0.01
    @trigger_fell = @fell_price - 0.01
    @stock_trading_info = {
      name: "名称",
      deal: base_price,
      y_close: base_price,
      t_open: base_price,
      date: "2015-12-12"
    }
  end

  describe Alert do
    it "should return nil if no deal info" do
      expect(
        Alert.new(@user, @stock, @rose_price, AlertType::Dynamic, "测试")).to be_nil
      nil_deal = @stock_trading_info
      nil_deal[:deal] = nil
      nil_deal[:y_close] = nil
      @stock.update_day_trading_info!(nil_deal)
      expect(
        Alert.new(@user, @stock, @rose_price, AlertType::Dynamic, "测试")).to be_nil
    end

    it "should init with info" do
      @stock.update_day_trading_info!(@stock_trading_info)
      alert = Alert.new(@user, @stock, @fell_price, AlertType::Dynamic, "测试")
      expect(alert).not_to be_nil
      expect(alert.direction).to be AlertDirection::Fell
      alert = Alert.new(@user, @stock, @rose_price, AlertType::Dynamic, "测试")
      expect(alert).not_to be_nil
      expect(alert.direction).to be AlertDirection::Rose
    end
  end

  describe AlertManager do
    before :each do
      @alert_manager = AlertManager.new
      @stock.update_day_trading_info!(@stock_trading_info)
      @fell_alert = Alert.new(@user, @stock, @fell_price, AlertType::Dynamic, "测试")
      @rose_alert = Alert.new(@user, @stock, @rose_price, AlertType::Dynamic, "测试")
    end

    it "should reject nil alert" do
      alert = Alert.new(@user, nil, @rose_price, AlertType::Dynamic, "测试")
      alerts = @alert_manager.add_alert(alert)
      expect(alerts).to be_nil
    end

    it "should accept valid alert" do
      alerts = @alert_manager.add_alert(@fell_alert)
      expect(alerts).not_to be_nil
    end

    it "should maintain alert order when add" do
      rnd = Random.new
      alerts = nil
      (0..3).each do
        price = rnd.rand(0..@fell_price)
        alert = Alert.new(@user, @stock, price, AlertType::Dynamic, "测试")
        alerts = @alert_manager.add_alert(alert)
      end
      alerts.reduce {|prev, cur | expect(prev.price).to be < cur.price and prev = cur}
      (0..3).each do
        price = rnd.rand(@rose_price..@rose_price+10)
        alert = Alert.new(@user, @stock, price, AlertType::Dynamic, "测试")
        alerts = @alert_manager.add_alert(alert)
      end
      alerts.reduce {|prev, cur | expect(prev.price).to be > cur.price and prev = cur}
    end

    it "should batch remove alerts for one user" do
    end

    it "should trigger sms alert if necessary" do
      content = ""
      allow(AStockMarket).to receive(:is_now_in_trading_time?).and_return(true)
      allow(SMSBao).to receive(:send_to) {|u,c| content = c}
      AlertManager.any_instance.stub(:freeze_gap).and_return(0)
      allow(@alert_manager).to receive(:@freeze_gap).and_return(0)
      @alert_manager.add_alert(@fell_alert)
      @stock_trading_info[:deal] = @trigger_fell
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(content =~ /下破/).not_to be_nil
      # here is a sleep strategy that we need to override
      @alert_manager.add_alert(@rose_alert)
      @stock_trading_info[:deal] = @trigger_rose
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(content =~ /下破/).not_to be_nil
    end
  end
end
