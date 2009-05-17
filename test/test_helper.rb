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

class SerializedRecord < ActiveRecord::Base
  # the field in the database that stores the binary data
  attr_accessor :raw_data

  def self.table_exists?() false end
  def self.columns()       []    end

  serialize_attributes :data do
    string  :title, :body
    integer :age
    float   :average
    time    :birthday
    boolean :active
  end

  before_save { |r| false } # cancel the save

  def self.transaction
    yield
  rescue ActiveRecord::Rollback
  end
end