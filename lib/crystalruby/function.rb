module CrystalRuby
  # This class represents a single Crystalized function.
  # Each such function belongs a shared lib (See: CrystalRuby::Library)
  # and is attached to a single owner (a class or a module).
  class Function
    include Typemaps
    include Config

    attr_accessor :owner, :method_name, :args, :returns, :function_body, :lib, :async, :block, :attached

    def initialize(method:, args:, returns:, function_body:, lib:, async: false, &block)
      self.owner = method.owner
      self.method_name = method.name
      self.args = args
      self.returns = returns
      self.function_body = function_body
      self.lib = lib
      self.async = async
      self.block = block
      self.attached = false
    end

    # This is where we write/overwrite the class and instance methods
    # with their crystalized equivalents.
    # We also perform JIT compilation and JIT attachment of the FFI functions.
    # Crystalized methods can be redefined without restarting, if running in a live-reloading environment.
    # If they are redefined with a different function body, the new function body
    # will result in a new digest and the FFI function will be recompiled and reattached.
    def define_crystalized_methods!(lib)
      func = self
      [owner, owner.singleton_class].each do |receiver|
        receiver.undef_method(method_name) if receiver.method_defined?(method_name)
        receiver.define_method(method_name) do |*args|
          unless lib.compiled?
            lib.build!
            return send(func.method_name, *args)
          end
          unless func.attached?
            should_reenter = func.attach_ffi_lib_functions!
            return send(func.method_name, *args) if should_reenter
          end
          # All crystalruby functions are executed on the reactor to ensure Crystal/Ruby interop code is executed
          # from a single same thread. (Needed to make GC and Fiber scheduler happy)
          # Type mapping (if required) is applied on arguments and on return values.
          func.map_retval(
            Reactor.schedule_work!(
              func.owner,
              func.ffi_name,
              *func.map_args(args),
              func.ffi_ret_type,
              async: func.async,
              lib: lib
            )
          )
        end
      end
    end

    # This is where we attach the top-level FFI functions of the shared object
    # to our library (yield and init) needed for successful operation of the reactor.
    # We also initialize the shared object (needed to start the GC) and
    # start the reactor, unless we are in single-thread mode.
    def attach_ffi_lib_functions!
      should_reenter = unwrapped?
      lib_file = lib.lib_file
      lib.methods.each_value(&:attach_ffi_func!)
      lib.singleton_class.class_eval do
        extend FFI::Library
        ffi_lib lib_file
        %i[yield init].each do |method_name|
          singleton_class.undef_method(method_name) if singleton_class.method_defined?(method_name)
          undef_method(method_name) if method_defined?(method_name)
        end
        attach_function :init, %i[string pointer], :void
        attach_function :yield, %i[], :int
      end

      if CrystalRuby.config.single_thread_mode
        Reactor.init_single_thread_mode!
      else
        Reactor.start!
      end
      Reactor.schedule_work!(lib, :init, lib.name, Reactor::ERROR_CALLBACK, :void, blocking: true, async: false)
      should_reenter
    end

    # Attaches the crystalized FFI functions to their related Ruby modules and classes.
    # If a wrapper block has been passed to the crystalize function,
    # then the we also wrap the crystalized function using a prepended Module.
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
      method_name = self.method_name
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
    rescue StandardError => e
      CrystalRuby.log_error("Error attaching #{method_name} as #{ffi_name} to #{owner.name}")
      CrystalRuby.log_error(e.message)
      CrystalRuby.log_error(e.backtrace.join("\n"))
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

    def ffi_name
      lib_fn_name + (async && !config.single_thread_mode ? "_async" : "")
    end

    def lib_fn_name
      @lib_fn_name ||= "#{owner.name.downcase.gsub("::", "_")}_#{method_name}_#{Digest::MD5.hexdigest(function_body)}"
    end

    def arg_type_map
      @arg_type_map ||= args.transform_values(&method(:build_type_map))
    end

    def lib_fn_args
      @lib_fn_args ||= arg_type_map.map { |k, arg_type|
        "_#{k} : #{arg_type[:lib_type]}"
      }.join(",") + (arg_type_map.empty? ? "" : ", ")
    end

    def lib_fn_arg_names
      @lib_fn_arg_names ||= arg_type_map.map { |k, _arg_type|
        "_#{k}"
      }.join(",") + (arg_type_map.empty? ? "" : ", ")
    end

    def return_type_map
      @return_type_map ||= build_type_map(returns)
    end

    def ffi_types
      @ffi_types ||= arg_type_map.map { |_k, arg_type| arg_type[:ffi_type] }
    end

    def arg_maps
      @arg_maps ||= arg_type_map.map { |_k, arg_type| arg_type[:arg_mapper] }
    end

    def ffi_ret_type
      @ffi_ret_type ||= return_type_map[:ffi_ret_type]
    end

    def register_custom_types!(lib)
      [*arg_type_map.values, return_type_map].map { |t| t[:crystal_ruby_type] }.each do |crystalruby_type|
        if crystalruby_type.is_a?(Types::TypeSerializer) && !crystalruby_type.anonymous?
          lib.register_type!(crystalruby_type)
        end
      end
    end

    def map_args(args)
      return args unless arg_maps.any?

      arg_maps.each_with_index do |argmap, index|
        next unless argmap

        args[index] = argmap[args[index]]
      end
      args
    end

    def map_retval(retval)
      return retval unless return_type_map[:retval_mapper]

      return_type_map[:retval_mapper][retval]
    end

    def chunk
      @chunk ||= Template::Function.render(
        {
          module_name: owner.name,
          lib_fn_name: lib_fn_name,
          fn_name: method_name,
          fn_body: function_body,
          callback_call: returns == :void ? "callback.call(thread_id)" : "callback.call(thread_id, converted)",
          callback_type: return_type_map[:ffi_type] == :void ? "UInt32 -> Void" : " UInt32, #{return_type_map[:lib_type]} -> Void",
          fn_args: arg_type_map.map { |k, arg_type| "#{k} : #{arg_type[:crystal_type]}" }.join(","),
          fn_ret_type: return_type_map[:crystal_type],
          lib_fn_args: lib_fn_args,
          lib_fn_arg_names: lib_fn_arg_names,
          lib_fn_ret_type: return_type_map[:lib_type],
          convert_lib_args: arg_type_map.map do |k, arg_type|
            "#{k} = #{arg_type[:convert_lib_to_crystal_type]["_#{k}"]}"
          end.join("\n    "),
          arg_names: args.keys.join(","),
          convert_return_type: return_type_map[:convert_crystal_to_lib_type]["return_value"],
          error_value: return_type_map[:error_value]
        }
      )
    end
  end
end
