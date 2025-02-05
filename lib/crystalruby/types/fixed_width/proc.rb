module CrystalRuby::Types
  PROC_REGISTERY = {}
  Proc = FixedWidth.build(error: "Proc declarations should contain a list of 0 or more comma separated argument types,"\
    "and a single return type (or Nil if it does not return a value)")

  def self.Proc(*types)
    proc_type = FixedWidth.build(:Proc, convert_if: [::Proc], inner_types: types,
                                        ffi_type: :pointer) do
      @data_offset = 4

      def self.cast!(rbval)
        raise "Value must be a proc" unless rbval.is_a?(::Proc)

        func = FFI::Function.new(FFI::Type.const_get(inner_types[-1].ffi_type.to_s.upcase), inner_types[0...-1].map do |v|
                                                                                              FFI::Type.const_get(v.ffi_type.to_s.upcase)
                                                                                            end) do |*args|
          args = args.map.with_index do |arg, i|
            arg = inner_types[i].new(arg) unless arg.is_a?(inner_types[i])
            inner_types[i].anonymous? ? arg.native : arg
          end
          return_val = rbval.call(*args)
          return_val = inner_types[-1].new(return_val) unless return_val.is_a?(inner_types[-1])
          return_val.memory
        end
        PROC_REGISTERY[func.address] = func
        func
      end

      def self.copy_to!(rbval, memory:)
        memory[4].write_pointer(rbval)
      end

      def invoke(*args)
        invoker = value
        invoker.call(memory[12].read_pointer, *args)
      end

      def value(native: false)
        FFI::VariadicInvoker.new(
          memory[4].read_pointer,
          [FFI::Type::POINTER, *(inner_types[0...-1].map { |v| FFI::Type.const_get(v.ffi_type.to_s.upcase) })],
          FFI::Type.const_get(inner_types[-1].ffi_type.to_s.upcase),
          { ffi_convention: :stdcall }
        )
      end

      def self.block_converter
        <<~CRYSTAL
          { #{
            inner_types.size > 1 ? "|#{inner_types.size.-(1).times.map { |i| "v#{i}" }.join(",")}|" : ""
          }
            #{
              inner_types[0...-1].map.with_index do |type, i|
                <<~CRYS
                  v#{i} = #{type.crystal_class_name}.new(v#{i}).return_value

                  callback_done_channel = Channel(Nil).new
                  result = nil
                  if Fiber.current == Thread.current.main_fiber
                    block_value = #{inner_types[-1].crystal_class_name}.new(__yield_to.call(#{inner_types.size.-(1).times.map { |i| "v#{i}" }.join(",")}))
                    result = #{inner_types[-1].anonymous? ? "block_value.native_decr" : "block_value"}
                    next #{inner_types.last == CrystalRuby::Types::Nil ? "result" : "result.not_nil!"}
                  else
                    CrystalRuby.queue_callback(->{
                      block_value = #{inner_types[-1].crystal_class_name}.new(__yield_to.call(#{inner_types.size.-(1).times.map { |i| "v#{i}" }.join(",")}))
                      result = #{inner_types[-1].anonymous? ? "block_value.native_decr" : "block_value"}
                      callback_done_channel.send(nil)
                    })
                  end
                  callback_done_channel.receive
                  #{inner_types.last == CrystalRuby::Types::Nil ? "result" : "result.not_nil!"}
                CRYS
              end.join("\n")
            }
          }
        CRYSTAL
      end
    end
  end
end
