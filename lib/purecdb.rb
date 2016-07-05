require "purecdb/version"
require "purecdb/base"
require "purecdb/reader"
require "purecdb/writer"

module PureCDB

  # Convenience alternative to PureCDB::Reader.new(target, *options, &block)
  def self.reader(target,*options, &block)
    PureCDB::Reader.new(target, *options, &block)
  end

  # Convenience alternative to PureCDB::Writer.new(target, *options, &block)
  def self.writer(target,*options, &block)
    PureCDB::Writer.new(target, *options, &block)
  end
end
