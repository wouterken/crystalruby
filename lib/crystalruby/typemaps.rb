# frozen_string_literal: true

module CrystalRuby
  module Typemaps
    CRYSTAL_TYPE_MAP = {
      char: "::Int8",             # In Crystal, :char is typically represented as Int8
      uchar: "::UInt8",           # Unsigned char
      int8: "::Int8",             # Same as :char
      uint8: "::UInt8",           # Same as :uchar
      short: "::Int16",           # Short integer
      ushort: "::UInt16",         # Unsigned short integer
      int16: "::Int16",           # Same as :short
      uint16: "::UInt16",         # Same as :ushort
      int: "::Int32",             # Integer, Crystal defaults to 32 bits
      uint: "::UInt32",           # Unsigned integer
      int32: "::Int32",           # 32-bit integer
      uint32: "::UInt32",         # 32-bit unsigned integer
      long: "::Int32 | Int64",    # Long integer, size depends on the platform (32 or 64 bits)
      ulong: "::UInt32 | UInt64", # Unsigned long integer, size depends on the platform
      int64: "::Int64",           # 64-bit integer
      uint64: "::UInt64",         # 64-bit unsigned integer
      long_long: "::Int64",       # Same as :int64
      ulong_long: "::UInt64",     # Same as :uint64
      float: "::Float32",         # Floating point number (single precision)
      double: "::Float64",        # Double precision floating point number
      bool: "::Bool",             # Boolean type
      void: "::Void",             # Void type
      string: "::String",         # String type
      pointer: "::Pointer(Void)"  # Pointer type
    }

    FFI_TYPE_MAP = CRYSTAL_TYPE_MAP.invert

    ERROR_VALUE = {
      char: "0i8", # In Crystal, :char is typically represented as Int8
      uchar: "0u8", # Unsigned char
      int8: "0i8", # Same as :char
      uint8: "0u8", # Same as :uchar
      short: "0i16", # Short integer
      ushort: "0u16", # Unsigned short integer
      int16: "0i16", # Same as :short
      uint16: "0u16", # Same as :ushort
      int: "0i32", # Integer, Crystal defaults to 32 bits
      uint: "0u32", # Unsigned integer
      int32: "0i32", # 32-bit integer
      uint32: "0u32", # 32-bit unsigned integer
      long: "0i64", # Long integer, size depends on the platform (32 or 64 bits)
      ulong: "0u64", # Unsigned long integer, size depends on the platform
      int64: "0_i64", # 64-bit integer
      uint64: "0_u64", # 64-bit unsigned integer
      long_long: "0_i64",  # Same as :int64
      ulong_long: "0_u64", # Same as :uint64
      float: "0.0f32",    # Floating point number (single precision)
      double: "0.0f64",   # Double precision floating point number
      bool: "false", # Boolean type
      void: "Void", # Void type
      string: '"".to_unsafe', # String type
      pointer: "Pointer(Void).null" # Pointer type
    }

    C_TYPE_MAP = CRYSTAL_TYPE_MAP.merge(
      {
        string: "Pointer(::UInt8)"
      }
    )

    C_TYPE_CONVERSIONS = {
      string: {
        from: "::String.new(%s.not_nil!)",
        to: "%s.to_unsafe"
      },
      void: {
        to: "nil"
      }
    }.tap do |hash|
      hash.define_singleton_method(:convert) do |type, dir, expr|
        if hash.key?(type)
          conversion_string = hash[type][dir]
          conversion_string =~ /%/ ? conversion_string % expr : conversion_string
        else
          expr
        end
      end
    end

    def build_type_map(crystalruby_type)
      crystalruby_type = CRType(&crystalruby_type) if crystalruby_type.is_a?(Proc)

      if Types::Type.subclass?(crystalruby_type) && crystalruby_type.ffi_primitive_type
        crystalruby_type = crystalruby_type.ffi_primitive_type
      end

      {
        ffi_type: ffi_type(crystalruby_type),
        ffi_ret_type: ffi_type(crystalruby_type),
        crystal_type: crystal_type(crystalruby_type),
        crystalruby_type: crystalruby_type,
        lib_type: lib_type(crystalruby_type),
        error_value: error_value(crystalruby_type),
        arg_mapper: if Types::Type.subclass?(crystalruby_type)
                      lambda { |arg|
                        arg = crystalruby_type.new(arg.memory) if arg.is_a?(Types::Type) && !arg.is_a?(crystalruby_type)
                        arg = crystalruby_type.new(arg) unless arg.is_a?(Types::Type)

                        Types::FixedWidth.increment_ref_count!(arg.memory) if arg.class < Types::FixedWidth

                        arg
                      }
                    end,
        retval_mapper: if Types::Type.subclass?(crystalruby_type)
                         lambda { |arg|
                           if arg.is_a?(Types::Type) && !arg.is_a?(crystalruby_type)
                             arg = crystalruby_type.new(arg.memory)
                           end
                           arg = crystalruby_type.new(arg) unless arg.is_a?(Types::Type)

                           Types::FixedWidth.decrement_ref_count!(arg.memory) if arg.class < Types::FixedWidth

                           crystalruby_type.anonymous? ? arg.native : arg
                         }
                       # Strings in Crystal are UTF-8 encoded by default
                       elsif crystalruby_type.equal?(:string)
                         ->(arg) { arg.force_encoding("UTF-8") }
                       end,
        convert_crystal_to_lib_type: ->(expr) { convert_crystal_to_lib_type(expr, crystalruby_type) },
        convert_lib_to_crystal_type: ->(expr) { convert_lib_to_crystal_type(expr, crystalruby_type) }
      }
    end

    def ffi_type(type)
      case type
      when Symbol then type
      when Class
        if type < Types::FixedWidth
          :pointer
        elsif type < Types::Primitive
          type.ffi_type
        end
      end
    end

    def lib_type(type)
      if type.is_a?(Class) && type < Types::FixedWidth
        "Pointer(::UInt8)"
      elsif type.is_a?(Class) && type < Types::Type
        C_TYPE_MAP.fetch(type.ffi_type)
      else
        C_TYPE_MAP.fetch(type)
      end
    rescue StandardError
      raise "Unsupported type #{type}"
    end

    def error_value(type)
      if type.is_a?(Class) && type < Types::FixedWidth
        "Pointer(::UInt8).null"
      elsif type.is_a?(Class) && type < Types::Type
        ERROR_VALUE.fetch(type.ffi_type)
      else
        ERROR_VALUE.fetch(type)
      end
    rescue StandardError
      raise "Unsupported type #{type}"
    end

    def crystal_type(type)
      if type.is_a?(Class) && type < Types::Type
        type.anonymous? ? type.native_type_expr : type.inspect
      else
        CRYSTAL_TYPE_MAP.fetch(type)
      end
    rescue StandardError
      raise "Unsupported type #{type}"
    end

    def convert_lib_to_crystal_type(expr, type)
      if type.is_a?(Class) && type < Types::Type
        expr = "#{expr}.not_nil!" unless type.nil?
        type.pointer_to_crystal_type_conversion(expr)
      elsif type == :void
        "nil"
      else
        "#{C_TYPE_CONVERSIONS.convert(type, :from, expr)}.not_nil!"
      end
    end

    def convert_crystal_to_lib_type(expr, type)
      if type.is_a?(Class) && type < Types::Type
        type.crystal_type_to_pointer_type_conversion(expr)
      else
        C_TYPE_CONVERSIONS.convert(type, :to, expr)
      end
    end
  end
end
