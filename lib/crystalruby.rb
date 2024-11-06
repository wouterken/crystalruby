# frozen_string_literal: true

require "ffi"
require "digest"
require "fileutils"
require "method_source"
require "pathname"

require_relative "crystalruby/config"
require_relative "crystalruby/version"
require_relative "crystalruby/typemaps"
require_relative "crystalruby/types"
require_relative "crystalruby/typebuilder"
require_relative "crystalruby/template"
require_relative "crystalruby/compilation"
require_relative "crystalruby/adapter"
require_relative "crystalruby/reactor"
require_relative "crystalruby/library"
require_relative "crystalruby/function"
require_relative "module"

module CrystalRuby
  module_function

  def initialized?
    !!@initialized
  end

  def initialize_crystal_ruby!
    return if initialized?

    check_crystal_ruby!
    check_config!
    @initialized = true
  end

  def check_crystal_ruby!
    return if system("which crystal > /dev/null 2>&1")

    msg = "Crystal executable not found. Please ensure Crystal is installed and in your PATH. " \
      "See https://crystal-lang.org/install/."

    if config.crystal_missing_ignore
      config.logger.error msg
    else
      raise msg
    end
  end

  def check_config!
    return if config.crystal_src_dir

    raise "Missing config option `crystal_src_dir`. \nProvide this inside crystalruby.yaml " \
      "(run `bundle exec crystalruby init` to generate this file with detaults)"
  end

  %w[debug info warn error].each do |level|
    define_method(:"log_#{level}") do |*msg|
      prefix = config.colorize_log_output ? "\e[33mcrystalruby\e[0m\e[90m [#{Thread.current.object_id}]\e[0m" : "[crystalruby] #{Thread.current.object_id}"

      config.logger.send(level, "#{prefix} #{msg.join(", ")}")
    end
  end

  def compile!
    CrystalRuby::Library.all.each(&:build!)
  end
end
