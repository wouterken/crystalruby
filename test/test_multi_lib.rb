# frozen_string_literal: true

require_relative "test_helper"

class TestMultiLib < Minitest::Test
  def test_two_libs_one_module
    Object.const_set(:AdderLib, Module.new {})

    AdderLib.class_eval do
      crystalize :int, async: false, lib: "adder"
      def add(a: :int, b: :int)
        a + b
      end

      crystalize :int, async: false, lib: "adder-2"
      def add_v2(a: :int, b: :int)
        a + b
      end
    end

    assert AdderLib.add(1, 2) == AdderLib.add_v2(1, 2)
  end

  def test_ropen_two_libs_one_module
    Object.const_set(:MathLib, Module.new {})

    MathLib.class_eval do
      crystalize  :int, async: true, lib: "math"
      def add(a: :int, b: :int)
        a + b
      end

      crystalize :int, async: true, lib: "math-2"
      def add_v2(a: :int, b: :int)
        a + b
      end
    end

    assert MathLib.add(1, 2) == MathLib.add_v2(1, 2)

    MathLib.class_eval do
      crystalize :int, async: true, lib: "math-lib"
      def mult(a: :int, b: :int)
        a + b
      end

      crystalize :int, async: true, lib: "math-lib-2"
      def mult_v2(a: :int, b: :int)
        a + b
      end
    end

    assert MathLib.mult(14, 2) == MathLib.mult_v2(14, 2)
  end
end
