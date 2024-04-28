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
      @paths_cache = {}
      @crystal_src_dir      = file_config.fetch("crystal_src_dir", "crystalruby")
      @crystal_codegen_dir  = file_config.fetch("crystal_codegen_dir", "generated")
      @crystal_project_root = file_config.fetch("crystal_project_root", Pathname.pwd)
      @debug                = file_config.fetch("debug", true)
      @verbose              = file_config.fetch("verbose", false)
      @single_thread_mode   = file_config.fetch("single_thread_mode", false)
      @colorize_log_output  = file_config.fetch("colorize_log_output", false)
      @log_level            = file_config.fetch("log_level", ENV.fetch("CRYSTALRUBY_LOG_LEVEL", "info"))
      @logger               = Logger.new(STDOUT)
      @logger.level         = Logger.const_get(@log_level.to_s.upcase)
    end

    def file_config
      @file_config ||= File.exist?("crystalruby.yaml") && begin
        YAML.safe_load(IO.read("crystalruby.yaml"))
      rescue StandardError
        nil
      end || {}
    end

    def self.define_directory_accessors!(parent, directory_node)
      case directory_node
      when Array then directory_node.each(&method(:define_directory_accessors!).curry[parent])
      when Hash
        directory_node.each do |par, children|
          define_directory_accessors!(parent, par)
          define_directory_accessors!(par, children)
        end
      else
        define_method(directory_node) do
          @paths_cache[directory_node] ||= Pathname.new(instance_variable_get(:"@#{directory_node}"))
        end
        define_method("#{directory_node}_abs") do
          @paths_cache["#{directory_node}_abs"] ||= parent ? send("#{parent}_abs") / Pathname.new(instance_variable_get(:"@#{directory_node}")) : send(directory_node)
        end
      end
    end

    define_directory_accessors!(nil, { crystal_project_root: { crystal_src_dir: [:crystal_codegen_dir] } })

    def log_level=(level)
      @logger.level = Logger.const_get(@log_level = level.to_s.upcase)
    end
  end

  extend Config
  def self.configure
    yield(config)
    @paths_cache = {}
  end
end
