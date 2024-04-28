# frozen_string_literal: true

require_relative "../test_helper"

class TestBool < Minitest::Test
  class BoolClass < CRType{ Bool }
  end

  def test_it_acts_like_a_bool
    bl = BoolClass[true]
    assert_equal bl, true
    bl = BoolClass[false]
    assert_equal bl, false
  end

  def test_it_works_with_nil
    bl = BoolClass[nil]
    assert_equal bl, false
  end

  crystalize
  def negate_bool(value: Bool, returns: Bool)
    !value
  end

  def test_it_negates
    assert_equal negate_bool(true), false
    assert_equal negate_bool(false), true
  end

end
