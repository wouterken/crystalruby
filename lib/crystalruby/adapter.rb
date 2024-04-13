module CrystalRuby
  module Adapter
    # Define a method to set the @crystalize proc if it doesn't already exist
    def crystalize(raw: false, async: false, **options, &block)
      (args,), returns = options.first
      args ||= {}
      raise "Arguments should be of the form name: :type. Got #{args}" unless args.is_a?(Hash)

      @crystalize_next = { raw: raw, async: async, args: args, returns: returns, block: block }
    end

    def crystal(raw: false, &block)
      inline_crystal_body = Template::InlineChunk.render(
        {
          module_name: name,
          body: block.source.lines[
            raw ? 2...-2 : 1...-1
          ].join("\n")
        }
      )
      CrystalRuby.write_chunk(self, body: inline_crystal_body)
    end

    def crtype(&block)
      TypeBuilder.with_injected_type_dsl(self) do
        TypeBuilder.build(&block)
      end
    end

    def json(&block)
      crtype(&block).serialize_as(:json)
    end

    def method_added(method_name)
      if @crystalize_next
        define_crystalized_method(method_name, instance_method(method_name))
        @crystalize_next = nil
      end
      super
    end

    def singleton_method_added(method_name)
      if @crystalize_next
        define_crystalized_method(method_name, singleton_method(method_name))
        @crystalize_next = nil
      end
      super
    end

    def define_crystalized_method(method_name, method)
      CrystalRuby.log_debug("Defining crystalized method #{name}.#{method_name}")
      CrystalRuby.instantiate_crystal_ruby! unless CrystalRuby.instantiated?

      function_body = method.source.lines[
        @crystalize_next[:raw] ? 2...-2 : 1...-1
      ].join("\n")

      MethodSource.instance_variable_get(:@lines_for_file).delete(method.source_location[0])
      lib_fname = "#{name.downcase}_#{method_name}_#{Digest::MD5.hexdigest(function_body)}"
      args, returns, block, async = @crystalize_next.values_at(:args, :returns, :block, :async)
      args ||= {}
      @crystalize_next = nil
      function = CrystalRuby.build_function(self, lib_fname, method_name, args, returns, function_body)
      CrystalRuby.write_chunk(self, name: function[:name], body: function[:body]) do
        CrystalRuby.log_debug("attaching #{lib_fname} to #{name}")
        extend FFI::Library
        ffi_lib CrystalRuby.config.crystal_lib_dir / CrystalRuby.config.crystal_lib_name
        if async
          attach_function lib_fname, "#{lib_fname}_async", function[:ffi_types] + %i[int pointer], :void,
                          blocking: true
        else
          attach_function lib_fname, function[:ffi_types], function[:ffi_ret_type], blocking: true
        end
        if block
          [self, singleton_class].each do |receiver|
            receiver.prepend(Module.new do
              define_method(method_name, &block)
            end)
          end
        end
      end

      [self, singleton_class].each do |receiver|
        receiver.define_method(method_name) do |*args|
          CrystalRuby.build! unless CrystalRuby.compiled?
          unless CrystalRuby.attached?
            CrystalRuby.attach!
            return send(method_name, *args) if block
          end
          args.each_with_index do |arg, i|
            args[i] = function[:arg_maps][i][arg] if function[:arg_maps][i]
          end

          result = Reactor.schedule_work!(self, lib_fname, *args, function[:ffi_ret_type], async: async)

          if function[:retval_map]
            function[:retval_map][result]
          else
            result
          end
        end
      end
    end
  end
end
