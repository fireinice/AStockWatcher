# coding: utf-8
FactoryGirl.define do
  factory :stock do
    code "000001"
    market "sh"

    factory :stock_with_day_info, :class => 'stock' do
      name "股票名"
      deal 13.45
      y_close 13.30
      t_open 13.20
      date "2015-12-12"

      factory :stock_no_deal, :class => 'stock' do
        deal nil
        y_close nil
      end

      initialize_with do
        s = new(code, market)
        s.update_day_trading_info!({ :name => name, :deal => deal,  :t_open => t_open,
                                    :y_close => y_close, :date => date})
        s
      end
    end

    factory :stock_with_buy_info, :class => 'stock' do
      buy_price 12.34
      buy_quantity 1000
      initialize_with do
        s = new(code, market)
        s.update_buy_info!(buy_price, buy_quantity)
        s
      end
    end

    initialize_with { new(code, market) }
  end

  # factory :post do
  #   title "Hello"
  #   association :user
  #   #association :author, :factory => :user #关联另一个用户，同时定义一个别名。
  # end
end
