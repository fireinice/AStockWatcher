# coding: utf-8
require_relative "../alert"
describe Alert do
  it "should return nil if no deal info" do
    stock = FactoryGirl.build(:stock_no_deal)
    user = FactoryGirl.build(:user)
    expect(Alert.new(user, stock, 12.50, AlertType::Dynamic, "测试"))
  end

  it "should init with info" do
  end
end
