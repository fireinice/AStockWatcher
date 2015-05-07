# coding: utf-8
require_relative "../../user"

FactoryGirl.define do
  factory :user do
    phone 18601012345
  end
  factory :usera, :class => 'user' do
    phone 18601013456
  end
  initialize_with { new(phone) }

end
