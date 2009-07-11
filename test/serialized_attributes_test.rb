require File.dirname(__FILE__) + '/test_helper'

class SerializedAttributeWithSerializedDataTest < ActiveSupport::TestCase
  @@current_time = Time.now.utc.midnight
  @@raw_hash     = {:title => 'abc', :age => 5, :average => 5.1, :birthday => @@current_time.xmlschema, :active => true}
  SerializedRecord.stubbed_raw_data = SerializedAttributes::Schema.encode(@@raw_hash)

  def setup
    @newbie  = SerializedRecordWithDefaults.new
    @record  = SerializedRecord.new
    @changed = SerializedRecord.new
    @record.raw_data  = SerializedRecord.stubbed_raw_data
    @changed.raw_data = SerializedRecord.stubbed_raw_data
    @changed.title    = 'def'
    @changed.age      = 6
  end

  test "existing model respects defaults from missing key" do
    assert !@record.data.key?('default_in_my_favor')
    assert @record.default_in_my_favor?
    assert_equal true, @record.data['default_in_my_favor']
    @record.default_in_my_favor = false
    assert !@record.default_in_my_favor?
    @record.default_in_my_favor = nil
    assert @record.default_in_my_favor?
  end

  test "new model respects integer defaults" do
    assert_equal 18, @newbie.age
  end

  test "new model respects string defaults" do
    assert_equal 'blank', @newbie.title
    assert_equal 'blank', @newbie.body
  end

  test "new model respects float defaults" do
    assert_equal 5.2, @newbie.average
  end

  test "new model respects boolean defaults" do
    assert  @newbie.active?
  end

  test "new model respects date defaults" do
    assert_equal Time.utc(2009, 1, 1), @newbie.birthday
  end

  test "reloads serialized data" do
    @changed.id = 481516
    assert_equal @record.title, @changed.reload(2342).title
    assert_equal @record.age,   @changed.age
  end

  test "initialized model is not changed" do
    @record.data
    assert !@record.data_changed?
  end

  test "#attribute_names contains serialized fields" do
    assert_equal %w(active age average birthday title), @record.attribute_names
    @record.body = 'a'
    assert_equal %w(active age average birthday body title), @record.attribute_names
  end

  test "initialization does not call writers" do
    def @record.title=(v)
      raise ArgumentError
    end
    assert_not_nil @record.data
  end

  test "ignores data with extra keys" do
    @record.raw_data = SerializedAttributes::Schema.encode(@@raw_hash.merge(:foo => :bar))
    assert_not_nil @record.title     # no undefined foo= error
    assert_equal false, @record.save # extra before_save cancels the operation
    assert_equal @@raw_hash.merge(:active => 1).stringify_keys, SerializedAttributes::Schema.decode(@record.raw_data)
  end

  test "reads strings" do
    assert_equal @@raw_hash[:title], @record.title
  end
  
  test "clears strings with nil" do
    assert @record.data.key?('title')
    @record.title = nil
    assert !@record.data.key?('title')
  end
  
  test "reads integers" do
    assert_equal @@raw_hash[:age], @record.age
  end
  
  test "parses integers from strings" do
    @record.age = '5.5'
    assert_equal 5, @record.age
  end
  
  test "clears integers with nil" do
    assert @record.data.key?('age')
    @record.age = nil
    assert !@record.data.key?('age')
  end
  
  test "clears integers with blank" do
    assert @record.data.key?('age')
    @record.age = ''
    assert !@record.data.key?('age')
  end
  
  test "reads floats" do
    assert_equal @@raw_hash[:average], @record.average
  end
  
  test "parses floats from strings" do
    @record.average = '5.5'
    assert_equal 5.5, @record.average
  end
  
  test "clears floats with nil" do
    assert @record.data.key?('average')
    @record.average = nil
    assert !@record.data.key?('average')
  end
  
  test "clears floats with blank" do
    assert @record.data.key?('average')
    @record.average = ''
    assert !@record.data.key?('average')
  end
  
  test "reads times" do
    assert_equal @@current_time, @record.birthday
  end
  
  test "parses times from strings" do
    t = 5.years.ago.utc.midnight
    @record.birthday = t.xmlschema
    assert_equal t, @record.birthday
  end
  
  test "clears times with nil" do
    assert @record.data.key?('birthday')
    @record.birthday = nil
    assert !@record.data.key?('birthday')
  end
  
  test "clears times with blank" do
    assert @record.data.key?('birthday')
    @record.birthday = ''
    assert !@record.data.key?('birthday')
  end
  
  test "reads booleans" do
    assert_equal true, @record.active
  end
  
  test "parses booleans from strings" do
    @record.active = '1'
    assert_equal true, @record.active
    @record.active = '0'
    assert_equal false, @record.active
  end
  
  test "parses booleans from integers" do
    @record.active = 1
    assert_equal true, @record.active
    @record.active = 0
    assert_equal false, @record.active
  end
  
  test "converts booleans to false with nil" do
    assert @record.data.key?('active')
    @record.active = nil
    assert !@record.data.key?('active')
  end
  
   test "attempts to re-encode data when saving" do
     assert_not_nil @record.title
     @record.raw_data = nil
     assert_equal false, @record.save # extra before_save cancels the operation
     assert_equal @@raw_hash.merge(:active => 1).stringify_keys, SerializedAttributes::Schema.decode(@record.raw_data)
   end
  
  test "knows untouched record is not changed" do
    assert !@record.data_changed?
    assert_equal [], @record.data_changed
  end
  
  test "knows updated record is changed" do
    assert @changed.data_changed?
    assert_equal %w(age title), @changed.data_changed.sort
  end
  
  test "tracks if field has changed" do
    assert !@record.title_changed?
    assert  @changed.title_changed?
  end
  
  test "tracks field changes" do
    assert_nil @record.title_change
    assert_equal %w(abc def), @changed.title_change
  end
end

class SerializedAttributeTest < ActiveSupport::TestCase
  def setup
    @record = SerializedRecord.new
  end

  test "encodes and decodes data successfully" do
    hash = {:a => 1, :b => 2}
    encoded = SerializedAttributes::Schema.encode(hash)
    assert_equal SerializedAttributes::Schema.decode(encoded), hash.stringify_keys
  end

  test "defines #data method on the model" do
    assert @record.respond_to?(:data)
    assert_equal @record.data, {}
  end

  attributes = {:string => [:title, :body], :integer => [:age], :float => [:average], :time => [:birthday], :boolean => [:active]}
  attributes.values.flatten.each do |attr|
    test "defines ##{attr} method on the model" do
      assert @record.respond_to?(attr)
      assert_nil @record.send(attr)
    end

    next if attr == :active
    test "defines ##{attr}_before_type_cast method on the model" do
      assert @record.respond_to?("#{attr}_before_type_cast")
      assert_equal "", @record.send("#{attr}_before_type_cast")
    end
  end

  test "defines #active_before_type_cast method on the model" do
    assert @record.respond_to?(:active_before_type_cast)
    assert_equal "0", @record.active_before_type_cast
  end

  attributes[:string].each do |attr|
    test "defines ##{attr}= method for string fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal 'abc', @record.send("#{attr}=", "abc")
      assert_equal 'abc', @record.data[attr.to_s]
    end

    test "does not define ##{attr}? method for string fields" do
      assert !@record.respond_to?("#{attr}?")
    end
  end

  attributes[:integer].each do |attr|
    test "defines ##{attr}= method for integer fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal 0, @record.send("#{attr}=", "abc")
      assert_equal 1, @record.send("#{attr}=", "1.2")
      assert_equal 1, @record.data[attr.to_s]
    end

    test "does not define ##{attr}? method for integer fields" do
      assert !@record.respond_to?("#{attr}?")
    end
  end

  attributes[:float].each do |attr|
    test "defines ##{attr}= method for float fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal 0.0, @record.send("#{attr}=", "abc")
      assert_equal 1.2, @record.send("#{attr}=", "1.2")
      assert_equal 1.2, @record.data[attr.to_s]
    end

    test "does not define ##{attr}? method for float fields" do
      assert !@record.respond_to?("#{attr}?")
    end
  end

  attributes[:time].each do |attr|
    test "defines ##{attr}= method for time fields" do
      assert @record.respond_to?("#{attr}=")
      t = Time.now.utc.midnight
      assert_equal t, @record.send("#{attr}=", t.xmlschema)
      assert_equal t, @record.data[attr.to_s]
    end

    test "does not define ##{attr}? method for boolean fields" do
      assert !@record.respond_to?("#{attr}?")
    end
  end

  attributes[:boolean].each do |attr|
    test "defines ##{attr}= method for boolean fields" do
      assert @record.respond_to?("#{attr}=")
      assert_equal false, @record.send("#{attr}=", 0)
      assert_equal true,  @record.send("#{attr}=", "1.2")
      assert_equal true,  @record.data[attr.to_s]
    end

    test "defines ##{attr}? method for float fields" do
      assert @record.respond_to?("#{attr}?")
    end
  end
end