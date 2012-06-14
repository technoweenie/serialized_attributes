# -*- coding: utf-8 -*-
require File.expand_path("../test_helper", __FILE__)

class SerializedAttributesTypesTest < ActiveSupport::TestCase

  test "boolean type encodes nil properly" do
    type = SerializedAttributes::Boolean.new

    assert_equal nil, type.encode(nil)
  end

  test "boolean type encodes blank string properly" do
    type = SerializedAttributes::Boolean.new

    assert_equal nil, type.encode("")
  end

  test "boolean type handles strings that look like booleans" do
    type = SerializedAttributes::Boolean.new

    assert_equal 0, type.encode("false")
    assert_equal 1,  type.encode("true")
  end

  test "boolean type encodes booleans properly" do
    type = SerializedAttributes::Boolean.new

    assert_equal 0, type.encode(false)
    assert_equal 1, type.encode(true)
  end

  test "boolean type parses properly" do
    type = SerializedAttributes::Boolean.new

    assert_equal false, type.parse(0)
    assert_equal true, type.parse(1)
    assert_equal false, type.parse("0")
    assert_equal true, type.parse("1")
    assert_equal nil, type.parse("")
  end

  test "array type does not modify inputs when parsing" do
    type = SerializedAttributes::Array.new :type => :integer
    params = { :language_ids => [""] }

    type.parse params[:language_ids]

    assert_equal({ :language_ids => [""] }, params)
  end

end
