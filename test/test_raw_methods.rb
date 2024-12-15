# frozen_string_literal: true

require_relative "test_helper"

class TestRawMethods < Minitest::Test
  def test_raw_methods

    Adder.class_eval do
      crystallize :int32, raw: true
      def add_raw(a: :int, b: :int)
        <<~CRYSTAL
          c = 0_u64
          a + b + c
        CRYSTAL
      end

      crystallize :int32, raw: true
      def add_raw_endless(a: :int, b: :int) = "c = 0_u64
        a + b + c"
    end

    assert Adder.add_raw(1, 2) == 3
    assert Adder.add_raw_endless(1, 2) == 3
  end
end
