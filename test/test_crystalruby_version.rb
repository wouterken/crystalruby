# frozen_string_literal: true

require_relative "test_helper"

class TestCrystalRubyVersion < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::CrystalRuby::VERSION
  end
end
