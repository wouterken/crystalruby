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

module CrystalRuby
  CR_SRC_FILES_PATTERN = "./**/*.cr"
  CR_COMPILE_MUX = Mutex.new

  module_function

  def build_function(owner, lib_fn_name, name, args, returns, body)
    log_debug(".build_function #{{ owner: owner, name: name, args: args, returns: returns, body: body[0..50] }}")

    arg_types = args.transform_values(&method(:build_type_map))
    return_type = build_type_map(returns)
    lib_fn_args = arg_types.map { |k, arg_type| "_#{k} : #{arg_type[:lib_type]}" }.join(",")
    lib_fn_args += ", " unless lib_fn_args.empty?
    lib_fn_arg_names = arg_types.map { |k, _arg_type| "_#{k}" }.join(",")
    lib_fn_arg_names += ", " unless lib_fn_args.empty?

    function_body = Template::Function.render(
      {
        module_name: owner.name,
        lib_fn_name: lib_fn_name,
        fn_name: name,
        fn_body: body,
        callback_call: returns == :void ? "callback.call(thread_id)" : "callback.call(thread_id, converted)",
        callback_type: return_type[:ffi_type] == :void ? "UInt32 -> Void" : " UInt32, #{return_type[:lib_type]} -> Void",
        fn_args: arg_types.map { |k, arg_type| "#{k} : #{arg_type[:crystal_type]}" }.join(","),
        fn_ret_type: return_type[:crystal_type],
        lib_fn_args: lib_fn_args,
        lib_fn_arg_names: lib_fn_arg_names,
        lib_fn_ret_type: return_type[:lib_type],
        convert_lib_args: arg_types.map do |k, arg_type|
          "#{k} = #{arg_type[:convert_lib_to_crystal_type]["_#{k}"]}"
        end.join("\n    "),
        arg_names: args.keys.join(","),
        convert_return_type: return_type[:convert_crystal_to_lib_type]["return_value"],
        error_value: return_type[:error_value]
      }
    )
    {
      name: name,
      body: function_body,
      retval_map: returns.is_a?(Types::TypeSerializer) ? ->(rv) { returns.prepare_retval(rv) } : nil,
      ffi_types: arg_types.map { |_k, arg_type| arg_type[:ffi_type] },
      arg_maps: arg_types.map { |_k, arg_type| arg_type[:mapper] },
      ffi_ret_type: return_type[:ffi_ret_type]
    }
  end

  def build_type_map(crystalruby_type)
    if crystalruby_type.is_a?(Types::TypeSerializer) && !crystalruby_type.anonymous?
      CrystalRuby.register_type!(crystalruby_type)
    end

    {
      ffi_type: ffi_type(crystalruby_type),
      ffi_ret_type: ffi_type(crystalruby_type),
      crystal_type: crystal_type(crystalruby_type),
      lib_type: lib_type(crystalruby_type),
      error_value: error_value(crystalruby_type),
      mapper: crystalruby_type.is_a?(Types::TypeSerializer) ? ->(arg) { crystalruby_type.prepare_argument(arg) } : nil,
      convert_crystal_to_lib_type: ->(expr) { convert_crystal_to_lib_type(expr, crystalruby_type) },
      convert_lib_to_crystal_type: ->(expr) { convert_lib_to_crystal_type(expr, crystalruby_type) }
    }
  end

  def ffi_type(type)
    case type
    when Symbol then type
    when Types::TypeSerializer then type.ffi_type
    end
  end

  def lib_type(type)
    if type.is_a?(Types::TypeSerializer)
      type.lib_type
    else
      Typemaps::C_TYPE_MAP.fetch(type)
    end
  rescue StandardError => e
    raise "Unsupported type #{type}"
  end

  def error_value(type)
    if type.is_a?(Types::TypeSerializer)
      type.error_value
    else
      Typemaps::ERROR_VALUE.fetch(type)
    end
  rescue StandardError => e
    raise "Unsupported type #{type}"
  end

  def crystal_type(type)
    if type.is_a?(Types::TypeSerializer)
      type.crystal_type
    else
      Typemaps::CRYSTAL_TYPE_MAP.fetch(type)
    end
  rescue StandardError => e
    raise "Unsupported type #{type}"
  end

  def convert_lib_to_crystal_type(expr, type)
    if type.is_a?(Types::TypeSerializer)
      type.lib_to_crystal_type_expr(expr)
    else
      Typemaps::C_TYPE_CONVERSIONS[type] ? Typemaps::C_TYPE_CONVERSIONS[type][:from] % expr : expr
    end
  end

  def convert_crystal_to_lib_type(expr, type)
    if type.is_a?(Types::TypeSerializer)
      type.crystal_to_lib_type_expr(expr)
    else
      Typemaps::C_TYPE_CONVERSIONS[type] ? Typemaps::C_TYPE_CONVERSIONS[type][:to] % expr : expr
    end
  end

  def self.instantiate_crystal_ruby!
    unless system("which crystal > /dev/null 2>&1")
      raise "Crystal executable not found. Please ensure Crystal is installed and in your PATH."
    end

    @instantiated = true
    %w[crystal_lib_dir crystal_main_file crystal_src_dir crystal_lib_name].each do |config_key|
      unless config.send(config_key)
        raise "Missing config option `#{config_key}`. \nProvide this inside crystalruby.yaml (run `bundle exec crystalruby init` to generate this file with detaults)"
      end
    end
    FileUtils.mkdir_p config.crystal_codegen_dir_abs
    FileUtils.mkdir_p config.crystal_lib_dir_abs
    FileUtils.mkdir_p config.crystal_src_dir_abs
    unless File.exist?(config.crystal_src_dir_abs / config.crystal_main_file)
      IO.write(
        config.crystal_src_dir_abs / config.crystal_main_file,
        "require \"./#{config.crystal_codegen_dir}/index\"\n"
      )
    end

    return if File.exist?(config.crystal_src_dir / "shard.yml")

    IO.write("#{config.crystal_src_dir}/shard.yml", <<~YAML)
      name: src
      version: 0.1.0
    YAML
  end

  def self.instantiated?
    @instantiated
  end

  def self.compiled?
    @compiled = get_current_crystal_lib_digest == get_cr_src_files_digest unless defined?(@compiled)
    @compiled
  end

  def self.attached?
    !!@attached
  end

  def self.register_type!(type)
    @types_cache ||= {}
    @types_cache[type.name] = type.type_defn
  end

  def type_modules
    (@types_cache || {}).map do |type_name, expr|
      parts = type_name.split("::")
      typedef = parts[0...-1].each_with_index.reduce("") do |acc, (part, index)|
        acc + "#{"  " * index}module #{part}\n"
      end
      typedef += "#{"  " * (parts.size - 1)}alias #{parts.last} = #{expr}\n"
      typedef + parts[0...-1].reverse.each_with_index.reduce("") do |acc, (_part, index)|
        acc + "#{"  " * (parts.size - 2 - index)}end\n"
      end
    end.join("\n")
  end

  def self.requires
    chunk_store.map do |function|
      function_data = function[:body]
      file_digest = Digest::MD5.hexdigest function_data
      fname = function[:name]
      "require \"./#{function[:owner].name}/#{fname}_#{file_digest}.cr\"\n"
    end.join("\n")
  end

  def self.build!
    log_debug(".build!")

    CR_COMPILE_MUX.synchronize do
      return if @compiled

      File.write config.crystal_codegen_dir_abs / "index.cr", Template::Index.render(
        type_modules: type_modules,
        requires: requires
      )
      if @compiled = CrystalRuby::Compilation.compile!(
        verbose: config.verbose,
        debug: config.debug
      )
        IO.write(digest_file_name, get_cr_src_files_digest)
      else
        File.delete(digest_file_name) if File.exist?(digest_file_name)
        raise "Error compiling crystal code"
      end
    end
  end

  def self.attach!
    log_debug(".attach!")
    @chunk_store.each do |function|
      function[:compile_callback]&.call
    end
    log_debug(".attach_crystal_ruby_lib. Single thread mode: #{config.single_thread_mode}")
    if config.single_thread_mode
      Reactor.init_single_thread_mode!
    else
      Reactor.start!
    end
    @attached = true
  end

  def self.get_cr_src_files_digest
    file_digests = Dir.glob(CR_SRC_FILES_PATTERN).sort.map do |file_path|
      content = File.read(file_path)
      Digest::MD5.hexdigest(content)
    end.join
    Digest::MD5.hexdigest(file_digests)
  end

  def self.digest_file_name
    @digest_file_name ||= config.crystal_lib_dir_abs / "#{config.crystal_lib_name}.digest"
  end

  def self.chunk_store
    @chunk_store ||= []
  end

  def self.get_current_crystal_lib_digest
    File.read(digest_file_name) if File.exist?(digest_file_name)
  end

  def self.write_chunk(owner, body:, name: Digest::MD5.hexdigest(body), &compile_callback)
    log_debug(".write_chunk!")
    chunk_store.delete_if { |chnk| chnk[:owner].name == owner.name && chnk[:name] == name }
    chunk_store << { owner: owner, name: name, body: body, compile_callback: compile_callback }
    FileUtils.mkdir_p(config.crystal_codegen_dir_abs)
    existing = Dir.glob("#{config.crystal_codegen_dir_abs}/**/*.cr")
    chunk_store.each do |function|
      log_debug(".processing_chunk", function[0..60])
      owner_name = function[:owner].name
      FileUtils.mkdir_p(config.crystal_codegen_dir_abs / owner_name)
      function_data = function[:body]
      fname = function[:name]
      file_digest = Digest::MD5.hexdigest function_data
      filename = config.crystal_codegen_dir_abs / owner_name / "#{fname}_#{file_digest}.cr"

      unless existing.delete(filename.to_s)
        log_debug("Chunk invalidated", filename.to_s)
        @attached = false
        @compiled = false
        File.write(filename, function_data)
      end
      existing.select do |f|
        f =~ /#{config.crystal_codegen_dir / owner_name / "#{fname}_[a-f0-9]{32}\.cr"}/
      end.each do |fl|
        File.delete(fl) unless fl.eql?(filename.to_s)
      end
    end
  end
end

require_relative "module"
