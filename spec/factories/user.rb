# coding: utf-8
require_relative "../../user"

FactoryGirl.define do
  factory :user do
    phone "18601012345"
  end
  initialize_with { new(phone) }

end
