# frozen_string_literal: true

require_relative "test_helper"

class TestRubyWrappedCrystalizedMethods < Minitest::Test
  module MyModule
    crystalize ->{ :int32 } do |a, b|
      result = super(a.to_i, b.to_i)
      result + 1
    end
    def add(a: :int32, b: :int32)
      a + b
    end
  end

  def test_ruby_wrapped
    assert MyModule.add("1", "2") == 4
    assert MyModule.add(300, "5") == 306
  end
end
