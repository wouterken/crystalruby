require "singleton"
require "yaml"
require "logger"

module CrystalRuby
  def self.config
    Config.instance
  end

  %w[debug info warn error].each do |level|
    define_singleton_method("log_#{level}") do |*msg|
      prefix = config.colorize_log_output ? "\e[33mcrystalruby\e[0m\e[90m [#{Thread.current.object_id}]\e[0m" : "[crystalruby] #{Thread.current.object_id}"

      config.logger.send(level, "#{prefix} #{msg.join(", ")}")
    end
  end

  # Define a nested Config class
  class Config
    include Singleton
    attr_accessor :debug, :verbose, :logger, :colorize_log_output, :single_thread_mode

    def initialize
      @debug = true
      @paths_cache = {}
      config = File.exist?("crystalruby.yaml") && begin
        YAML.safe_load(IO.read("crystalruby.yaml"))
      rescue StandardError
        nil
      end || {}
      @crystal_src_dir      = config.fetch("crystal_src_dir", "./crystalruby/src")
      @crystal_lib_dir      = config.fetch("crystal_lib_dir", "./crystalruby/lib")
      @crystal_main_file    = config.fetch("crystal_main_file", "main.cr")
      @crystal_lib_name     = config.fetch("crystal_lib_name", "crlib")
      @crystal_codegen_dir  = config.fetch("crystal_codegen_dir", "generated")
      @crystal_project_root = config.fetch("crystal_project_root", Pathname.pwd)
      @debug                = config.fetch("debug", true)
      @verbose              = config.fetch("verbose", false)
      @single_thread_mode   = config.fetch("single_thread_mode", false)
      @colorize_log_output  = config.fetch("colorize_log_output", false)
      @log_level            = config.fetch("log_level", ENV.fetch("CRYSTALRUBY_LOG_LEVEL", "info"))
      @logger               = Logger.new(STDOUT)
      @logger.level         = Logger.const_get(@log_level.to_s.upcase)
    end

    %w[crystal_main_file crystal_lib_name crystal_project_root].each do |method_name|
      define_method(method_name) do
        @paths_cache[method_name] ||= Pathname.new(instance_variable_get(:"@#{method_name}"))
      end
    end

    %w[crystal_codegen_dir].each do |method_name|
      abs_method_name = "#{method_name}_abs"
      define_method(abs_method_name) do
        @paths_cache[abs_method_name] ||= crystal_src_dir_abs / instance_variable_get(:"@#{method_name}")
      end

      define_method(method_name) do
        @paths_cache[method_name] ||= Pathname.new instance_variable_get(:"@#{method_name}")
      end
    end

    %w[crystal_src_dir crystal_lib_dir].each do |method_name|
      abs_method_name = "#{method_name}_abs"
      define_method(abs_method_name) do
        @paths_cache[abs_method_name] ||= crystal_project_root / instance_variable_get(:"@#{method_name}")
      end

      define_method(method_name) do
        @paths_cache[method_name] ||= Pathname.new instance_variable_get(:"@#{method_name}")
      end
    end

    def log_level=(level)
      @log_level = level
      @logger.level = Logger.const_get(level.to_s.upcase)
    end
  end

  def self.configure
    yield(config)
    @paths_cache = {}
  end
end
