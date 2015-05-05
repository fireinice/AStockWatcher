# coding: utf-8
require_relative "support/factory_girl"
require_relative "../alert"

describe Alert do
  before :each do
    @user = FactoryGirl.build(:user)
  end

  it "should return nil if no deal info" do
    stock = FactoryGirl.build(:stock_no_deal)
    expect(Alert.new(@user, stock, 12.50, AlertType::Dynamic, "测试")).to be_nil
    stock = FactoryGirl.build(:stock)
    expect(Alert.new(@user, stock, 12.50, AlertType::Dynamic, "测试")).to be_nil
  end

  it "should init with info" do
    stock = FactoryGirl.build(:stock_with_day_info)
    alert = Alert.new(@user, stock, 12.50, AlertType::Dynamic, "测试")
    expect(alert).not_to be_nil
    expect(alert.direction).to be AlertDirection::Fell
    alert = Alert.new(@user, stock, 14.50, AlertType::Dynamic, "测试")
    expect(alert).not_to be_nil
    expect(alert.direction).to be AlertDirection::Rose
  end
end
