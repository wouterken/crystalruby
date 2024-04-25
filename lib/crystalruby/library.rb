module CrystalRuby
  class Library
    include Typemaps
    include Config

    # *CR_ATTACH_MUX* and *CR_COMPILE_MUX* are used to only allow a single FFI compile or attach operation at once
    # to avoid a rare scenario where the same function is attached simultaneously across two or more threads.
    CR_COMPILE_MUX = Mutex.new
    CR_ATTACH_MUX = Mutex.new

    attr_accessor :name, :methods, :chunks, :root_dir, :lib_dir, :src_dir, :codegen_dir, :reactor

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
      self.chunks = []
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
      IO.write  main_file, "require \"./#{config.crystal_codegen_dir}/index\"\n" unless File.exist?(main_file)

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
          write_chunk(method.owner.name, method.name, func.chunk)
        end
      end
    end

    def main_file
      src_dir / "#{name}.cr"
    end

    def lib_file
      lib_dir / "#{name}_#{digest}"
    end

    def shard_file
      src_dir / "shard.yml"
    end

    def crystalize_chunk(mod, chunk_name, body)
      write_chunk(mod.name, chunk_name, body)
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
      end
    end

    def index_contents
      IO.read(codegen_dir / "index.cr")
    rescue StandardError
      ""
    end

    def register_type!(type)
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

    def requires
      chunks.map do |chunk|
        chunk_data = chunk[:body]
        file_digest = Digest::MD5.hexdigest chunk_data
        fname = chunk[:chunk_name]
        "require \"./#{chunk[:module_name]}/#{fname}_#{file_digest}.cr\"\n"
      end.join("\n")
    end

    def build!
      CR_COMPILE_MUX.synchronize do
        File.write codegen_dir / "index.cr", Template::Index.render(
          type_modules: type_modules,
          requires: requires
        )

        unless compiled?
          CrystalRuby::Compilation.compile!(
            verbose: config.verbose,
            debug: config.debug,
            src: main_file,
            lib: lib_file
          )
        end
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
      chunks << { module_name: module_name, chunk_name: chunk_name, body: body }
      existing = Dir.glob(codegen_dir / "**/*.cr")
      chunks.each do |chunk|
        module_name, chunk_name, body = chunk.values_at(:module_name, :chunk_name, :body)

        file_digest = Digest::MD5.hexdigest body
        filename = (codegen_dir / module_name / "#{chunk_name}_#{file_digest}.cr").to_s

        unless existing.delete(filename)
          methods.each_value(&:unattach!)
          @compiled = false
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
end
