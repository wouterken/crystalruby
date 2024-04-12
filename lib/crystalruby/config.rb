require "singleton"
require "yaml"

module CrystalRuby
  def self.config
    Config.instance
  end

  # Define a nested Config class
  class Config
    include Singleton
    attr_accessor :debug, :verbose

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
  end

  def self.configure
    yield(config)
    @paths_cache = {}
  end
end
