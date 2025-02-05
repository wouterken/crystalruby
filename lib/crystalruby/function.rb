require "forwardable"

module CrystalRuby
  # This class represents a single Crystalized function.
  # Each such function belongs a shared lib (See: CrystalRuby::Library)
  # and is attached to a single owner (a class or a module).
  class Function
    extend Forwardable
    include Typemaps
    include Config

    attr_accessor :original_method, :owner, :args, :returns, :function_body, :arity,
                  :lib, :async, :block, :attached, :ruby, :instance_method, :class_method

    def_delegators :@original_method, :name

    def initialize(method:, args:, returns:, lib:, function_body: nil, async: false, ruby: false, &block)
      self.original_method = method
      self.owner = method.owner
      self.args = args
      self.returns = returns
      self.function_body = function_body
      self.lib = lib
      self.async = async
      self.block = block
      self.attached = false
      self.class_method = owner.singleton_class? && owner.attached_object.class == Class
      self.instance_method = original_method.is_a?(UnboundMethod) && original_method.owner.ancestors.include?(CrystalRuby::Types::Type)
      self.ruby = ruby
      self.arity = args.keys.-([:__yield_to]).size
    end

    def crystal_supertype
      return nil unless original_method.owner.ancestors.include?(CrystalRuby::Types::Type)

      original_method.owner.crystal_supertype
    end

    # This is where we write/overwrite the class and instance methods
    # with their crystallized equivalents.
    # We also perform JIT compilation and JIT attachment of the FFI functions.
    # Crystalized methods can be redefined without restarting, if running in a live-reloading environment.
    # If they are redefined with a different function body, the new function body
    # will result in a new digest and the FFI function will be recompiled and reattached.
    def define_crystallized_methods!(lib)
      func = self
      receivers = instance_method ? [owner] : [owner, owner.singleton_class]
      receivers.each do |receiver|
        receiver.undef_method(name) if receiver.method_defined?(name)
        receiver.define_method(name) do |*args, &blk|
          unless func.attached?
            should_reenter = func.unwrapped?
            lib.build! unless lib.compiled?
            lib.attach! unless func.attached?
            return send(func.name, *args, &blk) if should_reenter
          end
          # All crystalruby functions are executed on the reactor to ensure Crystal/Ruby interop code is executed
          # from a single same thread. (Needed to make GC and Fiber scheduler happy)
          # Type mapping (if required) is applied on arguments and on return values.
          if args.length != func.arity
            raise ArgumentError,
                  "wrong number of arguments (given #{args.length}, expected #{func.arity})"
          end

          raise ArgumentError, "block given but function does not accept block" if blk && !func.takes_block?
          raise ArgumentError, "no block given but function expects block" if !blk && func.takes_block?

          args << blk if blk

          func.map_args!(args)
          args.unshift(memory) if func.instance_method

          ret_val = Reactor.schedule_work!(
            func.owner,
            func.ffi_name,
            *args,
            func.ffi_ret_type,
            async: func.async,
            lib: lib
          )

          func.map_retval(ret_val)
        end
      end
    end

    def register_callback!
      return unless ruby

      ret_type = ffi_ret_type == :string ? :pointer : ffi_ret_type
      @callback_func = FFI::Function.new(ret_type, ffi_types) do |*args|
        receiver = instance_method ? owner.new(args.shift) : owner
        ret_val = \
          if takes_block?
            block_arg = arg_type_map[:__yield_to][:crystalruby_type].new(args.pop)
            receiver.send(name, *unmap_args(args)) do |*args|
              args = args.map.with_index do |arg, i|
                arg = block_arg.inner_types[i].new(arg) unless arg.is_a?(block_arg.inner_types[i])
                arg.memory
              end
              return_val = block_arg.invoke(*args)
              return_val = block_arg.inner_types[-1].new(return_val) unless return_val.is_a?(block_arg.inner_types[-1])
              block_arg.inner_types[-1].anonymous? ? return_val.value : return_val
            end
          else
            receiver.send(name, *unmap_args(args))
          end
        unmap_retval(ret_val)
      end

      Reactor.schedule_work!(
        lib,
        :"register_#{name.to_s.gsub("?", "q").gsub("=", "eq").gsub("!", "bang")}_callback",
        @callback_func,
        :void,
        blocking: true,
        async: false
      )
    end

    # Attaches the crystallized FFI functions to their related Ruby modules and classes.
    # If a wrapper block has been passed to the crystallize function,
    # then the we also wrap the crystallized function using a prepended Module.
    def attach_ffi_func!
      argtypes = ffi_types
      rettype = ffi_ret_type
      if async && !config.single_thread_mode
        argtypes += %i[int pointer]
        rettype = :void
      end

      owner.extend FFI::Library unless owner.is_a?(FFI::Library)

      unless (owner.instance_variable_get(:@ffi_libs) || [])
             .map(&:name)
             .map(&File.method(:basename))
             .include?(File.basename(lib.lib_file))
        owner.ffi_lib lib.lib_file
      end

      if owner.method_defined?(ffi_name)
        owner.undef_method(ffi_name)
        owner.singleton_class.undef_method(ffi_name)
      end

      owner.attach_function ffi_name, argtypes, rettype, blocking: true
      around_wrapper_block = block
      method_name = name
      @attached = true
      return unless around_wrapper_block

      @around_wrapper ||= begin
        wrapper_module = Module.new {}
        [owner, owner.singleton_class].each do |receiver|
          receiver.prepend(wrapper_module)
        end
        wrapper_module
      end
      @around_wrapper.undef_method(method_name) if @around_wrapper.method_defined?(method_name)
      @around_wrapper.define_method(method_name, &around_wrapper_block)
    end

    def unwrapped?
      block && !@around_wrapper
    end

    def attached?
      @attached
    end

    def unattach!
      @attached = false
    end

    def owner
      class_method ? @owner.attached_object : @owner
    end

    def owner_name
      owner.name
    end

    def ffi_name
      lib_fn_name + (async && !config.single_thread_mode ? "_async" : "")
    end

    def lib_fn_name
      @lib_fn_name ||= "#{owner_name.downcase.gsub("::",
                                                   "_")}_#{name.to_s.gsub("?", "query").gsub("!", "bang").gsub("=",
                                                                                                               "eq")}_#{Digest::MD5.hexdigest(function_body.to_s)}"
    end

    def arg_type_map
      @arg_type_map ||= args.transform_values(&method(:build_type_map))
    end

    def lib_fn_args
      @lib_fn_args ||= begin
        lib_fn_args = arg_type_map.map do |k, arg_type|
          "_#{k} : #{arg_type[:lib_type]}"
        end
        lib_fn_args.unshift("_self : Pointer(::UInt8)") if instance_method
        lib_fn_args.join(",") + (lib_fn_args.empty? ? "" : ", ")
      end
    end

    def lib_fn_arg_names(skip_blocks = false)
      @lib_fn_arg_names ||= begin
        names = arg_type_map.keys.reject { |k, _v| skip_blocks && is_block_arg?(k) }.map { |k| "_#{k}" }
        names.unshift("self.memory") if instance_method
        names.join(",") + (names.empty? ? "" : ", ")
      end
    end

    def lib_fn_types
      @lib_fn_types ||= begin
        lib_fn_types = arg_type_map.map { |_k, v| v[:lib_type] }
        lib_fn_types.unshift("Pointer(::UInt8)") if instance_method
        lib_fn_types.join(",") + (lib_fn_types.empty? ? "" : ", ")
      end
    end

    def return_type_map
      @return_type_map ||= build_type_map(returns)
    end

    def ffi_types
      @ffi_types ||= begin
        ffi_types = arg_type_map.map { |_k, arg_type| arg_type[:ffi_type] }
        ffi_types.unshift(:pointer) if instance_method
        ffi_types
      end
    end

    def arg_maps
      @arg_maps ||= arg_type_map.map { |_k, arg_type| arg_type[:arg_mapper] }
    end

    def arg_unmaps
      @arg_unmaps ||= arg_type_map.reject { |k, _v| is_block_arg?(k) }.map { |_k, arg_type| arg_type[:retval_mapper] }
    end

    def ffi_ret_type
      @ffi_ret_type ||= return_type_map[:ffi_ret_type]
    end

    def custom_types
      @custom_types ||= begin
        types = [*arg_type_map.values, return_type_map].map { |t| t[:crystalruby_type] }
        types.unshift(owner) if instance_method
        types
      end
    end

    def register_custom_types!(lib)
      custom_types.each do |crystalruby_type|
        next unless Types::Type.subclass?(crystalruby_type)

        [*crystalruby_type.nested_types].uniq.each do |type|
          lib.register_type!(type)
        end
      end
    end

    def map_args!(args)
      return args unless arg_maps.any?

      refs = nil

      arg_maps.each_with_index do |argmap, index|
        next unless argmap

        mapped = argmap[args[index]]
        case mapped
        when CrystalRuby::Types::Type
          args[index] = mapped.memory
          (refs ||= []) << mapped
        else
          args[index] = mapped
        end
      end
      refs
    end

    def unmap_args(args)
      return args unless args.any?

      arg_unmaps.each_with_index do |argmap, index|
        next unless argmap

        args[index] = argmap[args[index]]
      end
      args
    end

    def map_retval(retval)
      return retval unless return_type_map[:retval_mapper]

      return_type_map[:retval_mapper][retval]
    end

    def unmap_retval(retval)
      return FFI::MemoryPointer.from_string(retval) if return_type_map[:ffi_ret_type] == :string
      return retval unless return_type_map[:arg_mapper]

      retval = return_type_map[:arg_mapper][retval]

      retval = retval.memory if retval.is_a?(CrystalRuby::Types::Type)
      retval
    end

    def takes_block?
      is_block_arg?(:__yield_to)
    end

    def is_block_arg?(arg_name)
      arg_name == :__yield_to && arg_type_map[arg_name] && arg_type_map[arg_name][:crystalruby_type].ancestors.select do |a|
        a < Types::Type
      end.map(&:typename).any?(:Proc)
    end

    def ruby_interface
      template = owner == Object ? Template::TopLevelRubyInterface : Template::RubyInterface
      @ruby_interface ||= template.render(
        {
          module_or_class: instance_method || class_method ? "class" : "module",
          receiver: instance_method ? "#{owner_name}.new(_self)" : owner_name,
          fn_scope: instance_method ? "" : "self.",
          superclass: instance_method || class_method ? "< #{crystal_supertype}" : nil,
          module_name: owner_name,
          lib_fn_name: lib_fn_name,
          fn_name: name,
          callback_name: "#{name.to_s.gsub("?", "q").gsub("=", "eq").gsub("!", "bang")}_callback",
          fn_body: function_body,
          block_converter: takes_block? ? arg_type_map[:__yield_to][:crystalruby_type].block_converter : "",
          callback_call: returns == :void ? "callback.call(thread_id)" : "callback.call(thread_id, converted)",
          callback_type: return_type_map[:ffi_type] == :void ? "UInt32 -> Void" : " UInt32, #{return_type_map[:lib_type]} -> Void",
          fn_args: arg_type_map
              .map { |k, arg_type| "#{is_block_arg?(k) ? "&" : ""}#{k} : #{arg_type[:crystal_type]}" }.join(","),
          fn_ret_type: return_type_map[:crystal_type],
          lib_fn_args: lib_fn_args,
          lib_fn_types: lib_fn_types,
          lib_fn_arg_names: lib_fn_arg_names,
          lib_fn_ret_type: return_type_map[:lib_type],
          convert_lib_args: arg_type_map.map do |k, arg_type|
                              "_#{k} = #{arg_type[:convert_crystal_to_lib_type]["#{k}"]}"
                            end.join("\n    "),
          arg_names: args.keys.reject(&method(:is_block_arg?)).join(", "),
          convert_return_type: return_type_map[:convert_lib_to_crystal_type]["return_value"],
          error_value: return_type_map[:error_value]
        }
      )
    end

    def chunk
      template = owner == Object ? Template::TopLevelFunction : Template::Function
      @chunk ||= template.render(
        {
          module_or_class: instance_method || class_method ? "class" : "module",
          receiver: instance_method ? "#{owner_name}.new(_self)" : owner_name,
          fn_scope: instance_method ? "" : "self.",
          superclass: instance_method || class_method ? "< #{crystal_supertype}" : nil,
          module_name: owner_name,
          lib_fn_name: lib_fn_name,
          fn_name: name,
          callback_name: "#{name.to_s.gsub("?", "q").gsub("=", "eq").gsub("!", "bang")}_callback",
          fn_body: function_body,
          block_converter: takes_block? ? arg_type_map[:__yield_to][:crystalruby_type].block_converter : "",
          callback_call: returns == :void ? "callback.call(thread_id)" : "callback.call(thread_id, converted)",
          callback_type: return_type_map[:ffi_type] == :void ? "UInt32 -> Void" : " UInt32, #{return_type_map[:lib_type]} -> Void",
          fn_args: arg_type_map
            .reject { |k, _v| is_block_arg?(k) }
            .map { |k, arg_type| "#{k} : #{arg_type[:crystal_type]}" }.join(","),
          fn_ret_type: return_type_map[:crystal_type],
          lib_fn_args: lib_fn_args,
          lib_fn_arg_names: lib_fn_arg_names,
          lib_fn_ret_type: return_type_map[:lib_type],
          convert_lib_args: arg_type_map.map do |k, arg_type|
            "#{k} = #{arg_type[:convert_lib_to_crystal_type]["_#{k}"]}"
          end.join("\n    "),
          arg_names: args.keys.reject(&method(:is_block_arg?)).join(", "),
          convert_return_type: return_type_map[:convert_crystal_to_lib_type]["return_value"],
          error_value: return_type_map[:error_value]
        }
      )
    end
  end
end
