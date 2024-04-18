# frozen_string_literal: true

module CrystalRuby
  module Typemaps
    CRYSTAL_TYPE_MAP = {
      char: "Int8",        # In Crystal, :char is typically represented as Int8
      uchar: "UInt8",      # Unsigned char
      int8: "Int8",        # Same as :char
      uint8: "UInt8",      # Same as :uchar
      short: "Int16",      # Short integer
      ushort: "UInt16",    # Unsigned short integer
      int16: "Int16",      # Same as :short
      uint16: "UInt16",    # Same as :ushort
      int: "Int32",        # Integer, Crystal defaults to 32 bits
      uint: "UInt32",      # Unsigned integer
      int32: "Int32",      # 32-bit integer
      uint32: "UInt32",    # 32-bit unsigned integer
      long: "Int32 | Int64", # Long integer, size depends on the platform (32 or 64 bits)
      ulong: "UInt32 | UInt64", # Unsigned long integer, size depends on the platform
      int64: "Int64",      # 64-bit integer
      uint64: "UInt64",    # 64-bit unsigned integer
      long_long: "Int64",  # Same as :int64
      ulong_long: "UInt64", # Same as :uint64
      float: "Float32",    # Floating point number (single precision)
      double: "Float64",   # Double precision floating point number
      bool: "Bool",        # Boolean type
      void: "Void",        # Void type
      string: "String"     # String type
    }

    ERROR_VALUE = {
      char: "0", # In Crystal, :char is typically represented as Int8
      uchar: "0", # Unsigned char
      int8: "0", # Same as :char
      uint8: "0",      # Same as :uchar
      short: "0",      # Short integer
      ushort: "0", # Unsigned short integer
      int16: "0", # Same as :short
      uint16: "0", # Same as :ushort
      int: "0", # Integer, Crystal defaults to 32 bits
      uint: "0", # Unsigned integer
      int32: "0", # 32-bit integer
      uint32: "0", # 32-bit unsigned integer
      long: "0", # Long integer, size depends on the platform (32 or 64 bits)
      ulong: "0", # Unsigned long integer, size depends on the platform
      int64: "0", # 64-bit integer
      uint64: "0", # 64-bit unsigned integer
      long_long: "0",  # Same as :int64
      ulong_long: "0", # Same as :uint64
      float: "0.0",    # Floating point number (single precision)
      double: "0.0",   # Double precision floating point number
      bool: "false", # Boolean type
      void: "Void", # Void type
      string: '"".to_unsafe' # String type
    }

    C_TYPE_MAP = CRYSTAL_TYPE_MAP.merge(
      {
        string: "Pointer(UInt8)"
      }
    )

    C_TYPE_CONVERSIONS = {
      string: {
        from: "String.new(%s)",
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
      {
        ffi_type: ffi_type(crystalruby_type),
        ffi_ret_type: ffi_type(crystalruby_type),
        crystal_type: crystal_type(crystalruby_type),
        lib_type: lib_type(crystalruby_type),
        error_value: error_value(crystalruby_type),
        arg_mapper: if crystalruby_type.is_a?(Types::TypeSerializer)
                      lambda { |arg|
                        crystalruby_type.prepare_argument(arg)
                      }
                    end,
        retval_mapper: if crystalruby_type.is_a?(Types::TypeSerializer)
                         lambda { |arg|
                           crystalruby_type.prepare_retval(arg)
                         }
                       end,
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
        C_TYPE_MAP.fetch(type)
      end
    rescue StandardError
      raise "Unsupported type #{type}"
    end

    def error_value(type)
      if type.is_a?(Types::TypeSerializer)
        type.error_value
      else
        ERROR_VALUE.fetch(type)
      end
    rescue StandardError
      raise "Unsupported type #{type}"
    end

    def crystal_type(type)
      if type.is_a?(Types::TypeSerializer)
        type.crystal_type
      else
        CRYSTAL_TYPE_MAP.fetch(type)
      end
    rescue StandardError
      raise "Unsupported type #{type}"
    end

    def convert_lib_to_crystal_type(expr, type)
      if type.is_a?(Types::TypeSerializer)
        type.lib_to_crystal_type_expr(expr)
      else
        C_TYPE_CONVERSIONS.convert(type, :from, expr)
      end
    end

    def convert_crystal_to_lib_type(expr, type)
      if type.is_a?(Types::TypeSerializer)
        type.crystal_to_lib_type_expr(expr)
      else
        C_TYPE_CONVERSIONS.convert(type, :to, expr)
      end
    end
  end
end
