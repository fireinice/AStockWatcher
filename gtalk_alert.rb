#!/usr/bin/env ruby
# coding: utf-8
require 'easy-gtalk-bot'
require 'yaml'

class GtalkAlert

  @@user_name = nil
  @@password = nil
  @@CONFIG_FILENAME = 'gtalk.yml'
  @@gtalk = nil

  def self.init(user_name, password)
    @@user_name = user_name
    @@password = password
    @@gtalk = GTalk::Bot.new(:email => @@user_name, :password => @@password)
    @@gtalk.get_online
  end

  if File.readable?(@@CONFIG_FILENAME)
    cfg = YAML.load(File.open(@@CONFIG_FILENAME))
    self.init(cfg['user_name'], cfg['password'])
  end

  def self.set_basic_info(user_name, password)
    cfg = {}
    cfg['user_name'] = user_name
    cfg['password'] = password
    File.open( @@CONFIG_FILENAME, 'w' ) do |out|
      YAML.dump(cfg , out)
    end
  end


  def self.send_to(phones, content)
    raise "gtalk is offline" if @@gtalk.nil?
    send(@@user_name, @@password, phones, content)
  end

  def self.send(user_name, password, phones, content)
    phones = [phones] if not phones.is_a?(Array)
    phones.each do |phone|
      bot.message(phone.strip,"#{content}")
    end
    return nil
  end
end


if $0 == __FILE__
  # GtalkAlert.set_basic_info(ARGV[0], ARGV[1])
  ret = GtalkAlert.send_to("zhzhqiang@gmail.com", "测试#{Time.now}")
  # puts ret
end
