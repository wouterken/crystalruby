# frozen_string_literal: true

require_relative "test_helper"

class TestCrystalizeDSL < Minitest::Test
  def test_simple_adder
    Adder.class_eval do
      crystalize :int, async: false
      def add(a: :int, b: :int)
        a + b
      end
    end

    assert Adder.add(1, 2) == 3
  end

  def test_reopen
    Adder.class_eval do
      crystalize ->{ :int }, async: false
      def mult(a: :int, b: :int)
        a * b
      end
    end

    assert Adder.mult(4, 2) == 8
  end

  def test_string_ops
    Adder.class_eval do
      crystalize async: false
      def atsrev(a: :string, b: :string, returns: :string)
        (a + b).reverse
      end
    end

    assert Adder.atsrev("one", "two") == "owteno"
  end
  
  crystalize
  def takes_two_arguments(a: Int32, b: Int32, yield: Proc(Int32), returns: Int32)
    yield 4
    3
  end

  def test_argument_count_errors
    assert_raises(ArgumentError) { takes_two_arguments(1) }
    assert_raises(ArgumentError) { takes_two_arguments(1, 2, 3, 4) }
    assert_equal(
      takes_two_arguments(1, 2) do 
      end, 3
    )
  end

  module CrystalizeSyntax
    CustomType = CRType{ Int32 }
  end

  include CrystalizeSyntax
  def test_crystalize_syntax

    CrystalizeSyntax.class_eval do


      crystalize lib: 'multi-compile', raw: true
      def sub_cust(a: Int32, b: Int64 | String, returns: Int32)
        "
        3
        "
      end

      crystalize lib: 'multi-compile', raw: true
      def sub_cust_heredoc(a: Int32, b: Int64 | String, returns: Int32)

      <<~CRYSTAL
        9
      CRYSTAL
      end

      crystalize ->{ Int32 }, lib: 'multi-compile'
      def sub a: Int32, b: Int32
        a - b
      end

      crystalize ->{ Int32 }, lib: 'multi-compile', raw: true
      def sub2(a: Int32, b: Int32) = "a - b"

      crystalize ->{ Int32 }, lib: 'multi-compile', raw: false
      def sub3(a: Int32, b: Int32) = a - b

      # Unusual spacing is intentional to
      # test method parsing.
      crystalize ->{ Int32 }, lib: 'multi-compile'
      def add \
          a: :int,

              b: :int

  a + b

      end


      crystalize :int, lib: 'multi-compile'
      def add_simple(a: :int, b: :int)
        a + b
      end

      crystal do
        temp = 1 + 2
      end


      crystal raw: true do
        <<~HD
        CONST3 = 1 + 2
        HD
      end
    end

    assert CrystalizeSyntax.add(4, 2) == 6
    assert CrystalizeSyntax.sub(4, 2) == 2
    assert CrystalizeSyntax.add_simple(4, 2) == 6
    assert CrystalizeSyntax.sub_cust(4, 88) == 3
  end
end
