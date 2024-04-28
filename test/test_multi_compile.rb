# frozen_string_literal: true

require_relative "test_helper"
class TestMultiCompile < Minitest::Test
  module MultiCompile
  end

  include MultiCompile

  def test_inline_crystal
    MultiCompile.class_eval do
      crystalize :int32, lib: "multi-compile"
      def add(a: :int32, b: :int32)
        a + b
      end
    end

    CrystalRuby::Library["multi-compile"].build!
    MultiCompile.add(1, 3)

    MultiCompile.class_eval do
      crystalize :int32, lib: "multi-compile"
      def mult(a: :int32, b: :int32)
        a * b
      end
    end

    CrystalRuby::Library["multi-compile"].build!

    MultiCompile.class_eval do
      crystalize -> { Int32 }
      def sub(a: Int32, b: Int32)
        a - b
      end
    end

    CrystalRuby::Library["multi-compile-2"].build!
    assert_equal MultiCompile.sub(4, 2), 2
    assert_equal MultiCompile.add(4, 2), 6
  end
end
