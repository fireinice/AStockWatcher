# coding: utf-8
module AlertType
  Rose = 1
  Fell = -1
end

class Alert
  def initialize(user, stock, price)
    @user = user
    @stock = stock
    @price = price

  end
end
