# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/test_helper'

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

end
