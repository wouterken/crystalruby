# frozen_string_literal: true

require_relative "test_helper"

class TestCrystalizeDSL < Minitest::Test
  def test_simple_adder
    Adder.class_eval do
      crystalize [a: :int, b: :int] => :int, async: false
      def add(a, b)
        a + b
      end
    end

    assert Adder.add(1, 2) == 3
  end

  def test_reopen
    Adder.class_eval do
      crystalize [a: :int, b: :int] => :int, async: false
      def mult(a, b)
        a * b
      end
    end

    assert Adder.mult(4, 2) == 8
  end

  def test_string_ops
    Adder.class_eval do
      crystalize [a: :string, b: :string] => :string, async: false
      def atsrev(a, b)
        (a + b).reverse
      end
    end

    assert Adder.atsrev("one", "two") == "owteno"
  end
end
