# frozen_string_literal: true

require_relative "test_helper"

class TestInlineCrystalBlocks < Minitest::Test
  module InlineCrystalModule
    crystal raw: true do
      <<~CRYSTAL
        def self.inline_crystal(a : Int32, b : Int32) : Int32
          return a + b
        end
      CRYSTAL
    end

    crystal lib: "inline-crystal-test" do
      def self.mult(a, b)
        a * b
      end
    end

    crystallize :int32
    def call_inline_crystal(a: :int32, b: :int32)
      TestInlineCrystalBlocks::InlineCrystalModule.inline_crystal(a, b)
    end

    crystallize :int32, lib: "inline-crystal-test"
    def call_inline_crystal_multi_lib(a: :int32, b: :int32)
      TestInlineCrystalBlocks::InlineCrystalModule.mult(a, b)
    end

    crystallize :int32, lib: "dangling-lib"
    def call_inline_crystal_bad_lib(a: :int32, b: :int32)
      TestInlineCrystalBlocks::InlineCrystalModule.mult(a, b)
    end
  end

  # Suppress compilation errors in cases where we expect them as part of the test.
  def suppress_compile_stdout
    original_log_level = CrystalRuby::Config.log_level
    original_verbose = CrystalRuby::Config.verbose
    CrystalRuby::Config.log_level = :info
    CrystalRuby::Config.verbose = false
    yield
  ensure
    CrystalRuby::Config.log_level = original_log_level
    CrystalRuby::Config.verbose = original_verbose
  end

  include InlineCrystalModule
  def test_inline_crystal
    assert call_inline_crystal(1, 2) == 3
    assert call_inline_crystal_multi_lib(3, 10) == 30
    assert_raises(StandardError){ suppress_compile_stdout{ call_inline_crystal_bad_lib(3, 10) } }
  end
end
