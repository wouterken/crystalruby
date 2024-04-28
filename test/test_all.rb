# frozen_string_literal: true

Dir["#{__dir__}/**/test_*.rb"].each do |file|
  require_relative file unless File.basename(file) == "test_all.rb"
end

require_relative "test_helper"
require "minitest/reporters"
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new()]
