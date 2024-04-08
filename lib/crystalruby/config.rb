require "singleton"
require "yaml"

module CrystalRuby
  def self.config
    Config.instance
  end

  # Define a nested Config class
  class Config
    include Singleton
    attr_accessor :debug, :crystal_src_dir, :crystal_lib_dir, :crystal_main_file, :crystal_lib_name

    def initialize
      # Set default configuration options
      @debug = true
      return unless File.exist?("crystalruby.yaml")

      @crystal_src_dir, @crystal_lib_dir, @crystal_main_file, @crystal_lib_name =
        YAML.safe_load(IO.read("crystalruby.yaml")).values_at("crystal_src_dir", "crystal_lib_dir", "crystal_main_file",
                                                              "crystal_lib_name")
    end
  end

  def self.configure
    setup
    yield(config)
  end
end
