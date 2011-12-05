require 'rubygems'

if ENV['VERSION']
  gem 'activerecord', ENV['VERSION']
end

require 'test/unit'
require 'active_record'
require 'active_support/test_case'

require File.dirname(__FILE__) + '/../init'

begin
  require 'ruby-debug'
  Debugger.start
rescue LoadError
end

module SerializableMethods
  def table_exists?
    false
  end

  def columns
    []
  end

  def column_defaults
    {}
  end

  def columns_hash
    {}
  end

  def primary_key
    "id"
  end

  def transaction
    yield
  rescue ActiveRecord::Rollback
  end
end

class SerializedRecord < ActiveRecord::Base
  extend SerializableMethods

  class << self
    attr_accessor :stubbed_raw_data
  end

  def self.find(n, options)
    if n != 481516 && options != 2342
      raise ArgumentError, "This is supposed to be a test!"
    end
    r = new
    r.id = 481516
    r.raw_data = @stubbed_raw_data
    r
  end

  attr_accessor :raw_data

  serialize_attributes :data do
    string  :title, :body
    integer :age
    float   :average
    time    :birthday
    boolean :active
    boolean :default_in_my_favor, :default => true
    array   :names
    array   :lottery_picks, :type => :integer
    hash    :extras, :types => {
        :num        => :integer,
        :started_at => :time
      }
  end

  before_save { |r| false } # cancel the save

  def add_to_transaction
  end
end

class SerializedRecordWithDefaults < ActiveRecord::Base
  extend SerializableMethods

  attr_accessor :raw_data

  serialize_attributes :data do
    string  :title, :body, :default => 'blank'
    integer :age,          :default => 18
    float   :average,      :default => 5.2
    time    :birthday,     :default => Time.utc(2009, 1, 1)
    boolean :active,       :default => true
    array   :names,        :default => %w(a b c)
    hash    :extras,       :default => {:a => 1}
    boolean :clearance,    :default => nil
    string  :symbol,       :default => :foo
  end

  before_save { |r| false } # cancel the save

  def add_to_transaction
  end
end
