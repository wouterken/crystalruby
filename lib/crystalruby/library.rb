# frozen_string_literal: true

module CrystalRuby
  class Library
    include Typemaps
    include Config

    # *CR_ATTACH_MUX* and *CR_COMPILE_MUX* are used to only allow a single FFI compile or attach operation at once
    # to avoid a rare scenario where the same function is attached simultaneously across two or more threads.
    CR_COMPILE_MUX = Mutex.new
    CR_ATTACH_MUX = Mutex.new

    attr_accessor :name, :methods, :exposed_methods, :chunks, :root_dir,
                  :lib_dir, :src_dir, :codegen_dir, :shards

    @libs_by_name = {}

    def self.all
      @libs_by_name.values
    end

    def self.[](name)
      @libs_by_name[name] ||= begin
        CrystalRuby.initialize_crystal_ruby! unless CrystalRuby.initialized?
        Library.new(name)
      end
    end

    # A Library represents a single Crystal shared object.
    # It holds code as either methods (invokable from Ruby and attached) or
    # anonymous chunks, which are just raw Crystal code.
    def initialize(name)
      self.name = name
      self.methods = {}
      self.exposed_methods = {}
      self.chunks = []
      self.shards = {}
      initialize_library!
    end

    # Bootstraps the library filesystem and generates top level index.cr and shard files if
    # these do not already exist.
    def initialize_library!
      @root_dir, @lib_dir, @src_dir, @codegen_dir = [
        config.crystal_src_dir_abs / name,
        config.crystal_src_dir_abs / name / "lib",
        config.crystal_src_dir_abs / name / "src",
        config.crystal_src_dir_abs / name / "src" / config.crystal_codegen_dir
      ].each do |dir|
        FileUtils.mkdir_p(dir)
      end
      IO.write main_file, "require \"./#{config.crystal_codegen_dir}/index\"\n" unless File.exist?(main_file)

      return if File.exist?(shard_file)

      IO.write(shard_file, <<~YAML)
        name: src
        version: 0.1.0
      YAML
    end

    # Generates and stores a reference to a new CrystalRuby::Function
    # and triggers the generation of the crystal code. (See write_chunk)
    def crystalize_method(method, args, returns, function_body, async, &block)
      CR_ATTACH_MUX.synchronize do
        methods.each_value(&:unattach!)
        method_key = "#{method.owner.name}/#{method.name}"
        methods[method_key] = Function.new(
          method: method,
          args: args,
          returns: returns,
          function_body: function_body,
          async: async,
          lib: self,
          &block
        ).tap do |func|
          func.define_crystalized_methods!(self)
          func.register_custom_types!(self)
          write_chunk(func.owner_name, method.name, func.chunk)
        end
      end
    end

    def expose_method(method, args, returns)
      CR_ATTACH_MUX.synchronize do
        methods.each_value(&:unattach!)
        method_key = "#{method.owner.name}/#{method.name}"
        methods[method_key] = Function.new(
          method: method,
          args: args,
          returns: returns,
          ruby: true,
          lib: self
        ).tap do |func|
          func.register_custom_types!(self)
          write_chunk(func.owner_name, method.name, func.ruby_interface)
        end
      end
    end

    def main_file
      src_dir / "#{name}.cr"
    end

    def lib_file
      lib_dir / FFI::LibraryPath.new("#{name}#{config.debug ? "-debug" : ""}", abi_number: digest).to_s
    end

    def shard_file
      src_dir / "shard.yml"
    end

    def crystalize_chunk(mod, chunk_name, body)
      write_chunk(mod.respond_to?(:name) ? name : "main", chunk_name, body)
    end

    def instantiated?
      @instantiated
    end

    def compiled?
      @compiled ||= File.exist?(lib_file) && chunks.all? do |chunk|
        chunk_data = chunk[:body]
        file_digest = Digest::MD5.hexdigest chunk_data
        fname = chunk[:chunk_name]
        index_contents.include?("#{chunk[:module_name]}/#{fname}_#{file_digest}.cr")
      end && shards_installed?
    end

    def shards_installed?
      shard_file_content = nil
      shards.all? do |k, v|
        dependencies ||= shard_file_contents["dependencies"]
        dependencies[k] == v
      end && CrystalRuby::Compilation.shard_check?(src_dir)
    end

    def index_contents
      IO.read(codegen_dir / "index.cr")
    rescue StandardError
      ""
    end

    def register_type!(type)
      write_chunk("types", type.crystal_class_name, build_type(type.crystal_class_name, type.type_defn))
    end

    def build_type(type_name, expr)
      parts = type_name.split("::")
      typedef = parts[0...-1].each_with_index.reduce("") do |acc, (part, index)|
        acc + "#{"  " * index}module #{part}\n"
      end
      typedef += "#{"  " * parts.size}#{expr}\n"
      typedef + parts[0...-1].reverse.each_with_index.reduce("") do |acc, (_part, index)|
        acc + "#{"  " * (parts.size - 2 - index)}end\n"
      end
    end

    def shard_file_contents
      @shard_file_contents ||= YAML.safe_load(IO.read(shard_file))
    rescue StandardError
      @shard_file_contents ||= { "name" => "src", "version" => "0.1.0", "dependencies" => {} }
    end

    def shard_file_contents=(contents)
      IO.write(shard_file, JSON.load(contents.to_json).to_yaml)
    end

    def shard_dependencies
      shard_file_contents["dependencies"] ||= {}
    end

    def require_shard(name, opts)
      @shards[name.to_s] = JSON.parse(opts.merge("_crystalruby_managed" => true).to_json)
      rewrite_shards_file!
    end

    def rewrite_shards_file!
      dependencies = shard_dependencies

      dirty = @shards.any? do |k, v|
        dependencies[k] != v
      end || (@shards.empty? && dependencies.any?)

      return unless dirty

      if @shards.empty?
        shard_file_contents.delete("dependencies")
      else
        shard_file_contents["dependencies"] = @shards
      end

      self.shard_file_contents = shard_file_contents
    end

    def requires
      Template::Type.render({}) +
        Template::Primitive.render({}) +
        Template::FixedWidth.render({}) +
        Template::VariableWidth.render({}) +
        chunks.map do |chunk|
          chunk_data = chunk[:body]
          file_digest = Digest::MD5.hexdigest chunk_data
          fname = chunk[:chunk_name]
          "require \"./#{chunk[:module_name]}/#{fname}_#{file_digest}.cr\"\n"
        end.join("\n") + shards.keys.map do |shard_name|
                           "require \"#{shard_name}\"\n"
                         end.join("\n")
    end

    def build!
      CR_COMPILE_MUX.synchronize do
        File.write codegen_dir / "index.cr", Template::Index.render(requires: requires)
        unless compiled?
          FileUtils.rm_f(lib_file)

          if shard_dependencies.any? && shards.empty?
            rewrite_shards_file!
          end

          CrystalRuby::Compilation.install_shards!(src_dir)
          CrystalRuby::Compilation.compile!(
            verbose: config.verbose,
            debug: config.debug,
            src: main_file,
            lib: "#{lib_file}.part"
          )
          FileUtils.mv("#{lib_file}.part", lib_file)
          attach!
        end
      end
    end

    def attach!
      CR_ATTACH_MUX.synchronize do
        lib_file = self.lib_file
        lib_methods = methods
        lib_methods.values.reject(&:ruby).each(&:attach_ffi_func!)
        singleton_class.class_eval do
          extend FFI::Library
          ffi_lib lib_file
          %i[yield init].each do |method_name|
            singleton_class.undef_method(method_name) if singleton_class.method_defined?(method_name)
            undef_method(method_name) if method_defined?(method_name)
          end
          attach_function :init, %i[string pointer pointer], :void
          attach_function :yield, %i[], :int
          lib_methods.each_value.select(&:ruby).each do |method|
            attach_function :"register_#{method.name.to_s.gsub("?", "q").gsub("=", "eq").gsub("!", "bang")}_callback", %i[pointer], :void
          end
        end

        if CrystalRuby.config.single_thread_mode
          Reactor.init_single_thread_mode!
        else
          Reactor.start!
        end

        Reactor.schedule_work!(self, :init, name, Reactor::ERROR_CALLBACK, Types::Type::ARC_MUTEX.to_ptr, :void,
                               blocking: true, async: false)
        methods.values.select(&:ruby).each(&:register_callback!)
      end
    end

    def digest
      Digest::MD5.hexdigest(File.read(codegen_dir / "index.cr")) if File.exist?(codegen_dir / "index.cr")
    end

    def self.chunk_store
      @chunk_store ||= []
    end

    def write_chunk(module_name, chunk_name, body)
      chunks.delete_if { |chnk| chnk[:module_name] == module_name && chnk[:chunk_name] == chunk_name }
      chunk = { module_name: module_name, chunk_name: chunk_name, body: body }
      chunks << chunk
      existing = Dir.glob(codegen_dir / "**/*.cr")

      current_index_contents = index_contents
      module_name, chunk_name, body = chunk.values_at(:module_name, :chunk_name, :body)

      file_digest = Digest::MD5.hexdigest body
      filename = (codegen_dir / module_name / "#{chunk_name}_#{file_digest}.cr").to_s

      unless current_index_contents.include?("#{module_name}/#{chunk_name}_#{file_digest}.cr")
        methods.each_value(&:unattach!)
        @compiled = false
      end

      unless existing.delete(filename)
        FileUtils.mkdir_p(codegen_dir / module_name)
        File.write(filename, body)
      end
      existing.select do |f|
        f =~ /#{config.crystal_codegen_dir / module_name / "#{chunk_name}_[a-f0-9]{32}\.cr"}/
      end.each do |fl|
        File.delete(fl) unless fl.eql?(filename)
      end
    end
  end
end
