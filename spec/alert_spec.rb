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
      allow(AStockMarket).to receive(:is_now_in_trading_time?).and_return(true)
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

    it "should trigger rose sms alert if necessary" do
      content = ""
      allow(SMSBao).to receive(:send_to) {|u,c| content = c}
      @alert_manager.add_alert(@fell_alert)
      @stock_trading_info[:deal] = @trigger_fell
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(content =~ /下破/).not_to be_nil
    end

    it "should trigger fell sms alert if necessary" do
      content = ""
      allow(SMSBao).to receive(:send_to) {|u,c| content = c}
      @alert_manager.add_alert(@rose_alert)
      @stock_trading_info[:deal] = @trigger_rose
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(content =~ /突破/).not_to be_nil
    end

    context "remove dynamic alerts" do
      it "should batch remove all dynamic alerts" do
        allow(SMSBao).to receive(:send_to) {|p,c| phone = p}
        @alert_manager.add_alert(@rose_alert)
        alert = Alert.new(@user, @stock, @rose_price + 1, AlertType::Dynamic, "测试")
        @alert_manager.add_alert(alert)
        @alert_manager.clear_all_dynamic_alerts

        @stock_trading_info[:deal] = @rose_price + 2
        @stock.update_day_trading_info!(@stock_trading_info)

        @alert_manager.check_alert(@stock)
        expect(SMSBao).not_to have_received(:send_to)
      end

      it "should not remove fix alerts" do
        allow(SMSBao).to receive(:send_to) {|p,c| phone = p}
        @alert_manager.add_alert(@rose_alert)
        alert = Alert.new(@user, @stock, @rose_price + 1, AlertType::Fixed, "测试")
        @alert_manager.add_alert(alert)
        @alert_manager.clear_all_dynamic_alerts

        @stock_trading_info[:deal] = @rose_price + 2
        @stock.update_day_trading_info!(@stock_trading_info)

        @alert_manager.check_alert(@stock)
        expect(SMSBao).to have_received(:send_to)
      end
    end

    it "should batch remove alerts for a stock of one user" do
      phone = nil
      allow(SMSBao).to receive(:send_to) {|p,c| phone = p}
      @alert_manager.add_alert(@rose_alert)

      usera = FactoryGirl.build(:usera)
      alert = Alert.new(usera, @stock, @rose_price, AlertType::Dynamic, "测试")
      @alert_manager.add_alert(alert)

      stocka = FactoryGirl.build(:stocka)
      stocka.update_day_trading_info!(@stock_trading_info)
      alert = Alert.new(@user, stocka, @rose_price, AlertType::Dynamic, "测试")
      @alert_manager.add_alert(alert)

      @alert_manager.remove_alerts(@user, @stock)

      @stock_trading_info[:deal] = @trigger_rose
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(phone).to eq(usera.phone)

      stocka.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(stocka)
      expect(SMSBao).to have_received(:send_to).twice
      expect(phone).to eq(@user.phone)
    end


    it "should auto switch after trigger dynamic alert" do
      content = ""
      allow(SMSBao).to receive(:send_to) {|u,c| content = c}
      @alert_manager.add_alert(@rose_alert)

      @stock_trading_info[:deal] = @trigger_rose
      @stock.update_day_trading_info!(@stock_trading_info)

      buy_price = 15
      buy_quantity = 1000
      @stock.update_buy_info!(buy_price, buy_quantity)

      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(content =~ /突破/).not_to be_nil

      now = Time.now
      allow(Time).to receive(:now).and_return(
                       now + @alert_manager.freeze_gap + 1)

      @stock_trading_info[:deal] = @trigger_fell
      @stock.update_day_trading_info!(@stock_trading_info)

      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to).twice
      expect(content =~ /下破/).not_to be_nil
    end

    it "should trigger alert one by one" do
      content = ""
      allow(SMSBao).to receive(:send_to) {|u,c| content = c}
      alert = Alert.new(@user, @stock, @rose_price, AlertType::Dynamic, "rose_one")
      @alert_manager.add_alert(alert)
      alert = Alert.new(@user, @stock, @rose_price+2, AlertType::Dynamic, "rose_two")
      @alert_manager.add_alert(alert)

      buy_price = 15
      buy_quantity = 1000
      @stock.update_buy_info!(buy_price, buy_quantity)

      @stock_trading_info[:deal] = @rose_price + 1
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to)
      expect(content =~ /rose_one/).not_to be_nil

      now = Time.now
      allow(Time).to receive(:now).and_return(
                       now + @alert_manager.freeze_gap + 1)

      @stock_trading_info[:deal] = @rose_price + 3
      @stock.update_day_trading_info!(@stock_trading_info)
      @alert_manager.check_alert(@stock)
      expect(SMSBao).to have_received(:send_to).twice
      expect(content =~ /rose_two/).not_to be_nil
    end

    context "trigger alert" do
      it "should block much more time if the stock not buyed" do
        allow(SMSBao).to receive(:send_to) {|u,c| content = c}
        @alert_manager.add_alert(@rose_alert)
        alert = Alert.new(@user, @stock, @rose_price + 1, AlertType::Dynamic, "测试")
        @alert_manager.add_alert(alert)

        @stock_trading_info[:deal] = @rose_price + 2
        @stock.update_day_trading_info!(@stock_trading_info)
        @alert_manager.check_alert(@stock)
        expect(SMSBao).to have_received(:send_to)

        now = Time.now
        allow(Time).to receive(:now).and_return(
                         now + @alert_manager.freeze_gap + 1)
        @stock_trading_info[:deal] = @rose_price
        @stock.update_day_trading_info!(@stock_trading_info)
        @alert_manager.check_alert(@stock)
        expect(SMSBao).to have_received(:send_to)
      end

      it "should block alert from same stock and same user for a while" do
        allow(SMSBao).to receive(:send_to) {|u,c| content = c}
        @alert_manager.add_alert(@fell_alert)
        @alert_manager.add_alert(@rose_alert)
        alert = Alert.new(@user, @stock, @rose_price+1, AlertType::Dynamic, "测试")
        @alert_manager.add_alert(alert)
        usera = FactoryGirl.build(:usera)
        alert = Alert.new(usera, @stock, @rose_price, AlertType::Dynamic, "测试")
        @alert_manager.add_alert(alert)

        stocka = FactoryGirl.build(:stocka)
        stocka.update_day_trading_info!(@stock_trading_info)
        alert = Alert.new(@user, stocka, @rose_price, AlertType::Dynamic, "测试")
        expect(alert).not_to be_nil
        @alert_manager.add_alert(alert)

        @stock_trading_info[:deal] = @rose_price + 2

        @stock.update_day_trading_info!(@stock_trading_info)
        @alert_manager.check_alert(@stock)
        expect(SMSBao).to have_received(:send_to).twice

        stocka.update_day_trading_info!(@stock_trading_info)
        @alert_manager.check_alert(stocka)
        expect(SMSBao).to have_received(:send_to).exactly(3).times
      end

      it "should just block alert for a while" do
        allow(SMSBao).to receive(:send_to) {|u,c| content = c}
        @alert_manager.add_alert(@rose_alert)
        alert = Alert.new(@user, @stock, @rose_price + 1, AlertType::Dynamic, "测试")
        @alert_manager.add_alert(alert)

        buy_price = 15
        buy_quantity = 1000
        @stock.update_buy_info!(buy_price, buy_quantity)
       @stock_trading_info[:deal] = @rose_price + 2
        @stock.update_day_trading_info!(@stock_trading_info)

        @alert_manager.check_alert(@stock)
        expect(SMSBao).to have_received(:send_to)

        now = Time.now
        allow(Time).to receive(:now).and_return(
                         now + @alert_manager.freeze_gap + 1)
        @stock_trading_info[:deal] = @rose_price
        @stock.update_day_trading_info!(@stock_trading_info)
        @alert_manager.check_alert(@stock)
        expect(SMSBao).to have_received(:send_to).twice
      end
    end
  end
end
