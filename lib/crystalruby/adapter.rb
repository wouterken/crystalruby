module CrystalRuby
  module Adapter
    # Use this method to annotate a Ruby method that should be crystalized.
    # Compilation and attachment of the method is done lazily.
    # You can force compilation by calling `CrystalRuby.compile!`
    # It's important that all code using crystalized methods is
    # loaded before any manual calls to compile.
    #
    # E.g.
    #
    # crystalize [a: :int32, b: :int32] => :int32
    # def add(a, b)
    #  a + b
    # end
    #
    # Pass `raw: true` to pass Raw crystal code to the compiler as a string instead.
    # (Useful for cases where the Crystal method body is not valid Ruby)
    # E.g.
    # crystalize raw: true [a: :int32, b: :int32] => :int32
    # def add(a, b)
    #   <<~CRYSTAL
    #   a + b
    #   CRYSTAL
    # end
    #
    # Pass `async: true` to make the method async.
    # Crystal methods will always block the currently executing Ruby thread.
    # With async: false, all other Crystal code will be blocked while this Crystal method is executing (similar to Ruby code with the GVL)
    # With async: true, several Crystal methods can be executing concurrently.
    #
    # Pass lib: "name_of_lib" to compile Crystal code into several distinct libraries.
    # This can help keep compilation times low, by packaging your Crystal code into separate shared objects.
    def crystalize(raw: false, async: false, lib: "crystalruby", **options, &block)
      (args,), returns = options.first || [[], :void]
      args ||= {}
      raise "Arguments should be of the form name: :type. Got #{args}" unless args.is_a?(Hash)

      @crystalize_next = {
        raw: raw,
        async: async,
        args: args,
        returns: returns,
        block: block,
        lib: lib
      }
    end

    # This method provides a useful DSL for defining Crystal types in pure Ruby.
    # These types can not be passed directly to Ruby, and must be serialized as either:
    #   JSON or
    #   C-Structures (WIP)
    #
    # See #json for an example of how to define arguments or return types for complex objects.
    # E.g.
    #
    # MyType = crtype{ Int32 | Hash(String, Array(Bool) | Float65 | Nil) }
    def crtype(&block)
      TypeBuilder.with_injected_type_dsl(self) do
        TypeBuilder.build(&block)
      end
    end

    # Use the json{} helper for defining complex method arguments or return types
    # that should be serialized to and from Crystal using JSON. (This conversion is applied automatically)
    #
    # E.g.
    # crystalize [a: json{ Int32 | Float64 | Nil } ] => NamedStruct(result: Int32 | Float64 | Nil)
    def json(&block)
      crtype(&block).serialize_as(:json)
    end

    # We trigger attaching of crystalized instance methods here.
    # If a method is added after a crystalize annotation we assume it's the target of the crystalize annotation.
    def method_added(method_name)
      define_crystalized_method(method_name, instance_method(method_name)) if @crystalize_next
      super
    end

    # We trigger attaching of crystalized class methods here.
    # If a method is added after a crystalize annotation we assume it's the target of the crystalize annotation.
    def singleton_method_added(method_name)
      define_crystalized_method(method_name, singleton_method(method_name)) if @crystalize_next
      super
    end

    # Use this method to define inline Crystal code that does not need to be bound to a Ruby method.
    # This is useful for defining classes, modules, performing set-up tasks etc.
    # See: docs for .crystalize to understand the `raw` and `lib` parameters.
    def crystal(raw: false, lib: "crystalruby", &block)
      inline_crystal_body = Template::InlineChunk.render(
        {
          module_name: name, body: extract_source(block, raw: raw)
        }
      )
      CrystalRuby::Library[lib].crystalize_chunk(
        self,
        Digest::MD5.hexdigest(inline_crystal_body),
        inline_crystal_body
      )
    end

    # We attach crystalized class methods here.
    # This function is responsible for
    # - Generating the Crystal source code
    # - Overwriting the method and class methods by the same name in the caller.
    # - Lazily triggering compilation and attachment of the Ruby method to the Crystal code.
    # - We also optionally prepend a block (if given) to the owner, to allow Ruby code to wrap around Crystal code.
    def define_crystalized_method(method_name, method)
      CrystalRuby.log_debug("Defining crystalized method #{name}.#{method_name}")

      args, returns, block, async, lib, raw = @crystalize_next.values_at(:args, :returns, :block, :async, :lib, :raw)
      @crystalize_next = nil

      CrystalRuby::Library[lib].crystalize_method(
        method,
        args,
        returns,
        extract_source(method, raw: raw),
        async,
        &block
      )
    end

    # Extract Ruby source to serve as Crystal code directly.
    # If it's a raw method, we'll strip the string delimiters at either end of the definition.
    # We need to clear the MethodSource cache here to allow for code reloading.
    def extract_source(method_or_block, raw: false)
      method_or_block.source.lines[raw ? 2...-2 : 1...-1].join("\n").tap do
        MethodSource.instance_variable_get(:@lines_for_file).delete(method_or_block.source_location[0])
      end
    end
  end
end
