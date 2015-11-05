# coding: utf-8
require 'yaml'
require "uri"
require 'net/http'

class SMSBao
  @@SMS_STATUS = {
    -1 => 'unknown error',
    0 => 'success',
    30 => 'password error',
    40 => 'bad account',
    41 => 'no money',
    42 => 'account expired',
    43 => 'IP denied',
    50 => 'content sensitive',
    51 => 'bad phone number',
  }
  @@CONFIG_FILENAME = 'smsbao_config.yml'
  @@user_name = nil
  @@password = nil

  def self.init(user_name, password)
    @@user_name = user_name
    @@password = password
  end

  if File.readable?(@@CONFIG_FILENAME)
    cfg = YAML.load(File.open(@@CONFIG_FILENAME))
    self.init(cfg['user_name'], cfg['password'])
  end

  def self.set_basic_info(user_name, password)
    require 'digest/md5'
    password = Digest::MD5.hexdigest password
    cfg = {}
    cfg['user_name'] = user_name
    cfg['password'] = password
    File.open( @@CONFIG_FILENAME, 'w' ) do |out|
      YAML.dump(cfg , out)
    end
  end


  def self.send_to(phones, content)
    send(@@user_name, @@password, phones, content)
  end

  def self.send(user_name, password, phones, content)
    result = nil
    phones = phones.join(",") if phones.is_a?(Array)
    api_url = "http://114.215.144.170/sms?u=#{user_name}&p=#{password}&m=#{phones}&c=#{URI.escape(content)}"
    result = self.fetch_data(api_url)
    # open(api_url) {|f|
    #   f.each_line {|line| result = line}
    # }
    result = result.to_i
    raise @@SMS_STATUS[result] if 0 != result
    return result
  end

  private
  def self.fetch_data(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host)
    http.open_timeout = 5
    res = Net::HTTP.get_response(uri)
    remote_data = res.body if res.is_a?(Net::HTTPSuccess)
  end

end


if $0 == __FILE__
  SMSBao.set_basic_info(ARGV[0], ARGV[1])
  # ret = SMSBao.send_to("", "测试#{Time.now}")
  # puts ret
end
