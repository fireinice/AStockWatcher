# coding: utf-8
require_relative "support/factory_girl"
require_relative "../alert"

FactoryGirl.find_definitions
describe Alert do
  it "should return nil if no deal info" do
    stock = FactoryGirl.build(:stock_no_deal)
    user = FactoryGirl.build(:user)
    expect(Alert.new(user, stock, 12.50, AlertType::Dynamic, "测试")).to be_nil
    stock = FactoryGirl.build(:stock)
    expect(Alert.new(user, stock, 12.50, AlertType::Dynamic, "测试")).to be_nil
  end

  it "should init with info" do
  end
end
