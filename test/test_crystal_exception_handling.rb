# frozen_string_literal: true

require_relative "test_helper"

class TestCrystalExceptionHandling < Minitest::Test
  module Exceptional
    crystalize [a: :int32, b: :int32] => :int32
    def throws(a, b)
      raise "Exception"
      a + b
    end

    crystalize [a: json { Hash(String, String) }] => :void
    def for_type_error
      puts "Expecting a Hash(String, String)"
    end
  end

  def test_exception_handling
    assert_raises(RuntimeError) { Exceptional.throws(1, 2) }
    assert_raises(ArgumentError) { Exceptional.for_type_error(1) }
  end
end
