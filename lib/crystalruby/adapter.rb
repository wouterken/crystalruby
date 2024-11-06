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
    # crystalize :int32
    # def add(a: :int32, b: :int32)
    #  a + b
    # end
    #
    # Pass `raw: true` to pass Raw crystal code to the compiler as a string instead.
    # (Useful for cases where the Crystal method body is not valid Ruby)
    # E.g.
    # crystalize :int32, raw: true
    # def add(a: :int32, b: :int32)
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
    # @param returns The return type of the method. Optional (defaults to :void).
    # @param [Hash] options The options hash.
    # @option options [Boolean] :raw (false) Pass raw Crystal code to the compiler as a string.
    # @option options [Boolean] :async (false) Mark the method as async (allows multiplexing).
    # @option options [String] :lib ("crystalruby") The name of the library to compile the Crystal code into.
    # @option options [Proc] :block An optional wrapper Ruby block that wraps around any invocations of the crystal code
    def crystalize( returns=:void, raw: false, async: false, lib: "crystalruby", &block)
      (self == TOPLEVEL_BINDING.receiver ? Object : self).instance_eval do
        @crystalize_next = {
          raw: raw,
          async: async,
          returns: returns,
          block: block,
          lib: lib
        }
      end
    end

    # Exposes a Ruby method to one or more Crystal libraries.
    # Type annotations follow the same rules as the `crystalize` method, but are
    # applied in reverse.
    # @param returns The return type of the method. Optional (defaults to :void).
    # @param [Hash] options The options hash.
    # @option options [Boolean] :raw (false) Pass raw Crystal code to the compiler as a string.
    # @option options [String] :libs (["crystalruby"]) The name of the Crystal librarie(s) to expose the Ruby code to.
    def expose_to_crystal( returns=:void, libs: ["crystalruby"])
      (self == TOPLEVEL_BINDING.receiver ? Object : self).instance_eval do
        @expose_next_to_crystal = {
          returns: returns,
          libs: libs
        }
      end
    end

    # Define a shard dependency
    # This dependency will be automatically injected into the shard.yml file for
    # the given library and installed upon compile if it is not already installed.
    def shard(shard_name, lib: 'crystalruby', **opts)
      CrystalRuby::Library[lib].require_shard(shard_name, **opts)
    end

    # Use this method to define inline Crystal code that does not need to be bound to a Ruby method.
    # This is useful for defining classes, modules, performing set-up tasks etc.
    # See: docs for .crystalize to understand the `raw` and `lib` parameters.
    def crystal(raw: false, lib: "crystalruby", &block)
      inline_crystal_body = respond_to?(:name) ? Template::InlineChunk.render(
        {
          module_name: name,
          body: SourceReader.extract_source_from_proc(block, raw: raw),
          mod_or_class: self.kind_of?(Class) && self < Types::Type ? "class" : "module",
          superclass: self.kind_of?(Class) && self < Types::Type ? "< #{self.crystal_supertype}" : ""
        }) :
        SourceReader.extract_source_from_proc(block, raw: raw)

      CrystalRuby::Library[lib].crystalize_chunk(
        self,
        Digest::MD5.hexdigest(inline_crystal_body),
        inline_crystal_body
      )
    end


    # This method provides a useful DSL for defining Crystal types in pure Ruby
    # MyType = CRType{ Int32 | Hash(String, Array(Bool) | Float65 | Nil) }
    # @param [Proc] block The block within which we build the type definition.
    def CRType(&block)
      TypeBuilder.build_from_source(block, context: self)
    end

    private

    # We trigger attaching of crystalized instance methods here.
    # If a method is added after a crystalize annotation we assume it's the target of the crystalize annotation.
    # @param [Symbol] method_name The name of the method being added.
    def method_added(method_name)
      define_crystalized_method(instance_method(method_name)) if should_crystalize_next?
      expose_ruby_method_to_crystal(instance_method(method_name)) if should_expose_next?
      super
    end

    # We trigger attaching of crystalized class methods here.
    # If a method is added after a crystalize annotation we assume it's the target of the crystalize annotation.
    # @note This method is called when a method is added to the singleton class of the object.
    # @param [Symbol] method_name The name of the method being added.
    def singleton_method_added(method_name)
      define_crystalized_method(singleton_method(method_name)) if should_crystalize_next?
      expose_ruby_method_to_crystal(singleton_method(method_name)) if should_expose_next?
      super
    end

    # Helper method to determine if the next method added should be crystalized.
    # @return [Boolean] True if the next method added should be crystalized.
    def should_crystalize_next?
      defined?(@crystalize_next) && @crystalize_next
    end

    # Helper method to determine if the next method added should be exposed to Crystal libraries.
    # @return [Boolean] True if the next method added should be exposed.
    def should_expose_next?
      defined?(@expose_next_to_crystal) && @expose_next_to_crystal
    end

    # This is where we extract the Ruby method metadata and invoke the Crystal::Library functionality
    # to compile a stub for the Ruby method into the Crystal library.
    def expose_ruby_method_to_crystal(method)
      returns, libs = @expose_next_to_crystal.values_at(:returns, :libs)
      @expose_next_to_crystal = nil

      args, source = SourceReader.extract_args_and_source_from_method(method)
      returns = args.delete(:returns) if args[:returns] && returns == :void
      args[:__yield_to] = args.delete(:yield) if args[:yield]
      src = <<~RUBY
        def #{method.name} (#{(args.keys - [:__yield_to]).join(", ")})
          #{source}
        end
      RUBY

      owner = method.owner.singleton_class? ? method.owner.attached_object : method.owner
      owner.class_eval(src)
      owner.instance_eval(src) unless method.kind_of?(UnboundMethod) && method.owner.ancestors.include?(CrystalRuby::Types::Type)
      method = owner.send(method.kind_of?(UnboundMethod) ? :instance_method : :method, method.name)

      libs.each do |lib|
        CrystalRuby::Library[lib].expose_method(
          method,
          args,
          returns,
        )
      end
    end

    # We attach crystalized class methods here.
    # This function is responsible for
    # - Generating the Crystal source code
    # - Overwriting the method and class methods by the same name in the caller.
    # - Lazily triggering compilation and attachment of the Ruby method to the Crystal code.
    # - We also optionally prepend a block (if given) to the owner, to allow Ruby code to wrap around Crystal code.
    # @param [Symbol] method_name The name of the method being added.
    # @param [UnboundMethod] method The method being added.
    def define_crystalized_method(method)
      CrystalRuby.log_debug("Defining crystalized method #{name}.#{method.name}")

      returns, block, async, lib, raw = @crystalize_next.values_at(:returns, :block, :async, :lib, :raw)
      @crystalize_next = nil

      args, source = SourceReader.extract_args_and_source_from_method(method, raw: raw)

      # We can safely claim the `yield` argument name for typing the yielded block
      # because this is an illegal identifier in Crystal anyway.
      args[:__yield_to] = args.delete(:yield) if args[:yield]
      returns = args.delete(:returns) if args[:returns] && returns == :void

      CrystalRuby::Library[lib].crystalize_method(
        method,
        args,
        returns,
        source,
        async,
        &block
      )
    end
  end
end

Module.prepend(CrystalRuby::Adapter)
BasicObject.prepend(CrystalRuby::Adapter)
BasicObject.singleton_class.prepend(CrystalRuby::Adapter)
