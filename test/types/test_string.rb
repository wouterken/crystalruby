# frozen_string_literal: true

require_relative "../test_helper"

class TestString < Minitest::Test
  class StringClass < CRType{ String }
  end

  def test_it_has_a_length
    ss = StringClass["Test This"]
    assert_equal 9, ss.length
  end

  def test_it_can_be_indexed
    ss = StringClass["Test This"]
    assert_equal "T", ss[0]
  end

  def test_it_can_be_overwritten
    ss = StringClass["Test This"]
    ss[0] = "W"
    assert_equal ss, "West This"
  end

  def test_shallow_copies_share_memory
    ss = StringClass["Test This"]
    ss2 = ss.dup
    ss[0] = "W"
    assert_equal ss2, "West This"
  end

  def test_deep_copies_dont_share_memory
    ss = StringClass["Test This"]
    ss2 = ss.deep_dup
    ss[0] = "W"
    assert_equal ss2, "Test This"
  end

  def test_it_has_a_ref_count
    ss = StringClass["Test This"]
    assert_equal ss.ref_count, 1
    ss2 = ss.dup
    assert_equal ss.ref_count, 2
    ss3 = ss2.dup
    assert_equal ss.ref_count, 3
    ss3 = nil
    ss2 = nil
    2.times{
      GC.start
      sleep 0.1
    }
    assert_equal ss.ref_count, 1
  end

  crystallize lib: "string_tests"
  def takes_string(a: String)
  end

  crystallize lib: "string_tests"
  def returns_string(a: String, returns: String)
    return a
  end

  crystallize lib: "string_tests"
  def returns_named_string(a: StringClass, returns: StringClass)
    return a
  end

  crystallize lib: "string_tests"
  def returns_crystal_created_named_string(returns: StringClass)
    return StringClass.new("Test")
  end

  def test_crystal_takes_string
    assert (takes_string("Test") || true)
  end

  def test_crystal_returns_string
    assert_equal returns_string("Test"), "Test"
  end

  def test_crystal_returns_named_string
    my_test_str = StringClass["Test"]
    assert_equal returns_named_string(my_test_str), StringClass["Test"]
  end

  def test_returns_crystal_created_named_string
    assert_equal returns_crystal_created_named_string(), StringClass["Test"]
  end
end
