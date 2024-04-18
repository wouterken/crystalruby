require "singleton"
require "yaml"
require "logger"

module CrystalRuby
  # Config mixin to easily access the configuration
  # from anywhere in the code
  module Config
    def config
      Configuration.instance
    end
  end

  # Defines our configuration singleton
  # Config can be specified through either:
  # - crystalruby.yaml OR
  # - CrystalRuby.configure block
  class Configuration
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
      @crystal_src_dir      = config.fetch("crystal_src_dir", "./crystalruby")
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

    %w[crystal_project_root].each do |method_name|
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

    %w[crystal_src_dir].each do |method_name|
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

  extend Config
  def self.configure
    yield(config)
    @paths_cache = {}
  end
end
