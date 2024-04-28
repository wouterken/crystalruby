# frozen_string_literal: true

require "bundler/gem_tasks"

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

task :test do
  require_relative "test/test_all"
end
