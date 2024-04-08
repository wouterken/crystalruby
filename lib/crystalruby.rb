require 'ffi'
require 'digest'
require 'fileutils'
require 'method_source'
require_relative "crystalruby/config"
require_relative "crystalruby/version"
require_relative "crystalruby/typemaps"

module CrystalRuby

  # Define a method to set the @crystalize proc if it doesn't already exist
  def crystalize(type=:src, **options, &block)
    (args,), returns = options.first
    args ||= {}
    raise "Arguments should be of the form name: :type. Got #{args}" unless args.kind_of?(Hash)
    @crystalize_next = {raw: type.to_sym == :raw, args:, returns:, block: }
  end


  def method_added(method_name)
    if @crystalize_next
      attach_crystalized_method(method_name)
      @crystalize_next = nil
    end
    super
  end

  def config
    CrystalRuby.config
  end

  def attach_crystalized_method(method_name)

    CrystalRuby.instantiate_crystal_ruby! unless CrystalRuby.instantiated?

    function_body = instance_method(method_name).source.lines[
      @crystalize_next[:raw] ? 2...-2 : 1...-1
    ].join("\n")

    fname = "#{name.downcase}_#{method_name}"
    args, returns, block = @crystalize_next.values_at(:args, :returns, :block)
    args ||= {}
    @crystalize_next = nil
    function = build_function(self, method_name, args, returns, function_body)

    CrystalRuby.write_function(self, **function) do
      extend FFI::Library
      ffi_lib "#{config.crystal_lib_dir}/#{config.crystal_lib_name}"
      attach_function "#{method_name}", fname, args.map(&:last), returns
      attach_function 'init!', 'init', [], :void
      [singleton_class, self].each do |receiver|
        receiver.prepend(Module.new do
          define_method(method_name, &block)
        end)
      end if block

      init!
    end

    [singleton_class, self].each do |receiver|
      receiver.prepend(Module.new do
        define_method(method_name) do |*args|
          CrystalRuby.compile! unless CrystalRuby.compiled?
          CrystalRuby.attach! unless CrystalRuby.attached?
          super(*args)
        end
      end)
    end
  end

  module_function


  def build_function(owner, name, args, returns, body)
    fnname = "#{owner.name.downcase}_#{name}"
    args ||= {}
    string_conversions = args.select { |_k, v| v.eql?(:string) }.keys
    function_body = <<~CRYSTAL
      module #{owner.name}
        def self.#{name}(#{args.map { |k, v| "#{k} : #{native_type(v)}" }.join(',')}) : #{native_type(returns)}
          #{body}
        end
      end

      fun #{fnname}(#{args.map { |k, v| "_#{k}: #{lib_type(v)}" }.join(',')}): #{lib_type(returns)}
        #{args.map { |k, v| "#{k} = #{convert_to_native_type("_#{k}", v)}" }.join("\n\t")}
        #{convert_to_return_type("#{owner.name}.#{name}(#{args.keys.map { |k| "#{k}" }.join(',')})", returns)}
      end
    CRYSTAL

    {
      name: fnname,
      body: function_body
    }
  end

  def lib_type(type)
    Typemaps::C_TYPE_MAP[type]
  end

  def native_type(type)
    Typemaps::CRYSTAL_TYPE_MAP[type]
  end

  def convert_to_native_type(expr, outtype)
    Typemaps::C_TYPE_CONVERSIONS[outtype] ? Typemaps::C_TYPE_CONVERSIONS[outtype][:from] % expr : expr
  end

  def convert_to_return_type(expr, outtype)
    Typemaps::C_TYPE_CONVERSIONS[outtype] ? Typemaps::C_TYPE_CONVERSIONS[outtype][:to] % expr : expr
  end

  def self.instantiate_crystal_ruby!
    raise "Crystal executable not found. Please ensure Crystal is installed and in your PATH." unless system("which crystal > /dev/null 2>&1")
    @instantiated = true
    %w[crystal_lib_dir crystal_main_file crystal_src_dir crystal_lib_name].each do |config_key|
      raise "Missing config option `#{config_key}`. \nProvide this inside crystalruby.yaml (run `bundle exec crystalruby init` to generate this file with detaults)" unless config.send(config_key)
    end
    FileUtils.mkdir_p "#{config.crystal_src_dir}/generated"
    FileUtils.mkdir_p "#{config.crystal_lib_dir}"
    unless File.exist?("#{config.crystal_src_dir}/#{config.crystal_main_file}")
      IO.write("#{config.crystal_src_dir}/#{config.crystal_main_file}", "require \"./generated/index\"\n")
    end
    unless File.exist?("#{config.crystal_src_dir}/shard.yml")
      IO.write("#{config.crystal_src_dir}/shard.yml", <<~CRYSTAL)
      name: src
      version: 0.1.0
      CRYSTAL
    end
  end

  def self.instantiated?
    @instantiated
  end

  def self.compiled?
    @compiled
  end

  def self.attached?
    !!@attached
  end

  def self.compile!
    return unless @block_store
    index_content = <<~CRYSTAL
    FAKE_ARG = "crystal"
    fun init(): Void
      GC.init
      ptr = FAKE_ARG.to_unsafe
      LibCrystalMain.__crystal_main(1, pointerof(ptr))
    end
    CRYSTAL

    index_content += @block_store.map do |function|
      function_data = function[:body]
      file_digest = Digest::MD5.hexdigest function_data
      fname = function[:name]
      "require \"./#{function[:owner].name}/#{fname}_#{file_digest}.cr\"\n"
    end.join("\n")

    File.write("#{config.crystal_src_dir}/generated/index.cr", index_content)
    begin
      lib_target = "#{Dir.pwd}/#{config.crystal_lib_dir}/#{config.crystal_lib_name}"
      Dir.chdir(config.crystal_src_dir) do
        config.debug ?
          `crystal build -o #{lib_target} #{config.crystal_main_file}` :
          `crystal build --release --no-debug -o #{lib_target} #{config.crystal_main_file}`
      end

      @compiled = true
    rescue StandardError => e
      puts 'Error compiling crystal code'
      puts e
      File.delete("#{config.crystal_src_dir}/generated/index.cr")
    end
  end

  def self.attach!
    @block_store.each do |function|
      function[:compile_callback].call
    end
    @attached = true
  end

  def self.write_function(owner, name:, body:, &compile_callback)
    @compiled = File.exist?("#{config.crystal_src_dir}/generated/index.cr") unless defined?(@compiled)
    @block_store ||= []
    @block_store << {owner: owner, name: name, body: body, compile_callback: compile_callback}
    FileUtils.mkdir_p("#{config.crystal_src_dir}/generated")
    existing = Dir.glob("#{config.crystal_src_dir}/generated/**/*.cr")
    @block_store.each do |function|
      owner_name = function[:owner].name
      FileUtils.mkdir_p("#{config.crystal_src_dir}/generated/#{owner_name}")
      function_data = function[:body]
      fname = function[:name]
      file_digest = Digest::MD5.hexdigest function_data
      filename = "#{config.crystal_src_dir}/generated/#{owner_name}/#{fname}_#{file_digest}.cr"
      unless existing.delete(filename)
        @compiled = false
        @attached = false
        File.write(filename, function_data)
      end
      existing.select do |f|
        f =~ %r{#{config.crystal_src_dir}/generated/#{owner_name}/#{fname}_[a-f0-9]{32}\.cr}
      end.each do |fl|
        File.delete(fl) unless fl.eql?(filename)
      end
    end
  end
end

require_relative "module"
