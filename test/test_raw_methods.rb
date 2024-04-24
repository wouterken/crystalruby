# frozen_string_literal: true

require_relative "test_helper"

class TestRawMethods < Minitest::Test
  def test_raw_methods

    Adder.class_eval do
      crystalize [a: :int, b: :int] => :int, raw: true
      def add_raw(a, b)
        <<~CRYSTAL
          c = 0_u64
          a + b + c
        CRYSTAL
      end
    end

    assert Adder.add_raw(1, 2) == 3
  end
end
