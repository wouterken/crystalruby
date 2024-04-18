# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "crystalruby"
require "debug"
require "minitest/autorun"

CrystalRuby.configure do |config|
  config.verbose = true
  config.colorize_log_output = true
  config.single_thread_mode = !!ENV["CRYSTAL_RUBY_SINGLE_THREAD_MODE"]
end

FileUtils.rm_rf File.expand_path("./crystalruby") if ENV["RESET_CRYSTALRUBY_COMPILE_CACHE"]
CrystalRuby.initialize_crystal_ruby!

module Adder
end
