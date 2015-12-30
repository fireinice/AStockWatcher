# coding: utf-8
class MongoInterface
  require "mongo"
  Mongo::Logger.logger.level = ::Logger::FATAL
  @@client = Mongo::Client.new('mongodb://127.0.0.1:27017/scrapy')

  def self.get_status(code)
    code = code[2..-1] if code.start_with?('s')
    ret_list = []
    @@client[:stocks].find(:code => code).each do |item|
      ret_list << item
    end
    return nil  if ret_list.empty?
    raise "more than one code matched" unless 1 == ret_list.length
    ret_list[0]
  end
end

class HKStocksList < MongoInterface
  def self.get_status()
    codes = []
    @@client[:wiki_hk_stocks_list].find().each do |item|
      codes |= item["codes"]
    end
    codes
  end
end

if $0 == __FILE__
  puts HKStocksList.get_status()
end
