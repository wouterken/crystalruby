# frozen_string_literal: true

require_relative "test_helper"

class TestInlineCrystalBlocks < Minitest::Test
  module InlineCrystalModule
    crystal raw: true do
      <<~SQL
        def self.inline_crystal(a : Int32, b : Int32) : Int32
          return a + b
        end
      SQL
    end

    crystal lib: "inline-crystal-test" do
      def self.mult(a, b)
        a * b
      end
    end

    crystalize [a: :int32, b: :int32] => :int32
    def call_inline_crystal(a, b)
      TestInlineCrystalBlocks::InlineCrystalModule.inline_crystal(a, b)
    end

    crystalize [a: :int32, b: :int32] => :int32, lib: "inline-crystal-test"
    def call_inline_crystal_multi_lib(a, b)
      TestInlineCrystalBlocks::InlineCrystalModule.mult(a, b)
    end

    # crystalize [a: :int32, b: :int32] => :int32, lib: "dangling-lib"
    # def call_inline_crystal_bad_lib(a, b)
    #   TestInlineCrystal::InlineCrystalModule.mult(a, b)
    # end
  end

  include InlineCrystalModule
  def test_inline_crystal
    assert call_inline_crystal(1, 2) == 3
    assert call_inline_crystal_multi_lib(3, 10) == 30
    # refute(begin; call_inline_crystal_bad_lib(3, 10); rescue LoadError; false end)
  end
end
