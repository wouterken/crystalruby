# frozen_string_literal: true

require_relative "../test_helper"

class TestNumbers < Minitest::Test
  class Int32Class < CRType{ Int32 }
  end

  def test_int32
    assert_equal 4, Int32Class.memsize
    assert_equal 4, Int32Class.memsize
    assert_equal 4, Int32Class.new(0).memsize
    assert_equal 4, Int32Class.new(4).value
    assert Int32Class.new(0).primitive?
  end

  crystalize
  def can_take_anon_int32(value: Int32)
    value * 2
  end

  crystalize
  def can_take_named_int32(value: Int32Class)
    value * 2
  end

  crystalize
  def can_return_named_int32(value: UInt64, returns: Int32Class)
    return (value * 2).to_i32
  end

  crystalize
  def can_return_anonymous_int32(value: UInt64, returns: Int32)
    return (value * 2).to_i32
  end

  def test_can_take_anon_int32
    assert can_take_anon_int32(2) || true
  end

  def test_can_take_named_int32
    assert can_take_named_int32(2) || true
    i32 = Int32Class.new(2)
    assert can_take_named_int32(i32) || true
  end

  def test_can_return_named_int32
    assert_equal can_return_named_int32(Int32Class[15]), 30
  end

  def test_can_return_anonymous_int32
    assert_equal can_return_anonymous_int32(15), 30
  end
end
