# coding: utf-8
FactoryGirl.define do
  factory :stock do
    code 000001
    market sh
    buy_price 12.34
    buy_quantity 1000
    deal 13.45
    y_close 13.30

    factory :stock_no_deal, :class => 'stock' do
      deal nil
      y_close nil
    end
  end

  # factory :post do
  #   title "Hello"
  #   association :user
  #   #association :author, :factory => :user #关联另一个用户，同时定义一个别名。
  # end
end
