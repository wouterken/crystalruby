require "singleton"
require "yaml"

module CrystalRuby
  def self.config
    Config.instance
  end

  # Define a nested Config class
  class Config
    include Singleton
    attr_accessor :debug, :crystal_src_dir, :crystal_lib_dir, :crystal_main_file,
                  :crystal_lib_name, :crystal_codegen_dir

    def initialize
      @debug = true
      config = File.exist?("crystalruby.yaml") && begin
        YAML.safe_load(IO.read("crystalruby.yaml"))
      rescue StandardError
        nil
      end || {}
      @crystal_src_dir     = config.fetch("crystal_src_dir", "./crystalruby/src")
      @crystal_lib_dir     = config.fetch("crystal_lib_dir", "./crystalruby/lib")
      @crystal_main_file   = config.fetch("crystal_main_file", "main.cr")
      @crystal_lib_name    = config.fetch("crystal_lib_name", "crlib")
      @crystal_codegen_dir = config.fetch("crystal_codegen_dir", "generated")
      @debug               = config.fetch("debug", "true")
    end
  end

  def self.configure
    yield(config)
  end
end
