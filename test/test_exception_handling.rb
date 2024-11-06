# frozen_string_literal: true

require_relative "test_helper"

class TestExceptionHandling < Minitest::Test
  module Exceptional
    crystalize
    def throws(a: :int32, b: :int32, returns: :int32)
      raise "Exception"
      a + b
    end

    crystalize
    def for_type_error(a: Int32)
      puts "Expecting a Hash(String, String)"
    end
  end

  def test_exception_handling
    assert_raises(RuntimeError) { Exceptional.throws(1, 2) }
    assert_raises(RuntimeError) { Exceptional.for_type_error("Test") }
  end
end