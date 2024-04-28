# frozen_string_literal: true

require_relative "test_helper"

class TestExposeToCrystal < Minitest::Test

  crystalize :int
  def call_ruby_from_crystal(a: Int32, b: Int32)
    ruby_call(a, b)
  end

  expose_to_crystal ->{ Int32 }
  def ruby_call(a: Int32, b: Int32)
    a + b % [a,b].min
  end

  def test_simple_ruby_call
    assert_equal call_ruby_from_crystal(14, 7), 14
  end

  crystalize :int
  def will_call_ruby(seed: Int32)
    initial = ruby_call(seed + 1, seed + 2) * 3
    result = ruby_yield(initial) do |value|
      res = value - 4
      res
    end
    result
  end

  expose_to_crystal ->{ Int32 }
  def ruby_yield(initial: Int32, yield: Proc(Int32, Int32))
    initial += yield 14
    initial += yield 28
    initial += yield 32
    return initial
  end

  def test_bidirectional_calls
    [1,9,15,54,88].each do |seed|
      assert_equal(
        # Crystal method, performs simple Ruby method call and call with callbacks.
        will_call_ruby(seed),
        # Pure Ruby equivalent.
        # Invoke ruby_call directly, and replicate the yield logic.
        ruby_call(seed + 1, seed + 2) * 3 + (14 - 4) + (28 - 4) + (32 - 4)
      )
    end
  end
end
