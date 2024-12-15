# frozen_string_literal: true

require_relative "test_helper"
require "benchmark"

crystal do
  TOP_LEVEL_CONSTANT = "At the very top!"

  def top_level_method
    TOP_LEVEL_CONSTANT
  end
end

crystallize :int, raw: true
def top_level_crystallized_method
  %Q{ 88 + 12 }
end

expose_to_crystal ->{ Int32 }
def top_level_ruby_method
  33
end

crystallize ->{ Int32 }
def call_top_level_ruby_method
  top_level_ruby_method
end

class TestTopLevelCrystal < Minitest::Test
  module AccessTopLevelCrystal
    crystallize :string
    def access_top_level_constant
      top_level_method
    end
  end

  def test_top_level_crystal
    assert AccessTopLevelCrystal.access_top_level_constant == "At the very top!"
    assert top_level_crystallized_method == 100
  end

  def test_top_level_exposed_ruby
    assert_equal call_top_level_ruby_method, 33
  end
end
