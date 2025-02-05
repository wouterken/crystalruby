module CrystalRuby
  module Types
    class Primitive < Type
      # Primitives just store the Ruby value directly
      # (Or read it from memory if passed a pointer)
      def initialize(rbval)
        super(rbval)
        self.value = rbval.is_a?(FFI::Pointer) ? rbval.send("read_#{ffi_type}") : rbval
      end

      # Read a value from a pointer at a given index
      # (Type can be a byte-array, pointer or numeric type)
      def self.fetch_single(pointer, native: false)
        # Nothing to fetch for Nils
        return if memsize.zero?

        if numeric?
          pointer.send("read_#{ffi_type}")
        elsif primitive?
          single = new(pointer.send("read_#{ffi_type}"))
          if native
            single.value
          else
            single
          end
        end
      end

      # Write a data type into a pointer at a given index
      # (Type can be a byte-array, pointer or numeric type)
      def self.write_single(pointer, value)
        # Dont need to write nils
        return if memsize.zero?

        pointer.send("write_#{ffi_type}", to_ffi_repr(value))
      end

      # Fetch an array of a given data type from a list pointer
      # (Type can be a byte-array, pointer or numeric type)
      def self.fetch_multi(pointer, size, native: false)
        if numeric?
          pointer.send("get_array_of_#{ffi_type}", 0, size)
        elsif primitive?
          pointer.send("get_array_of_#{ffi_type}", 0, size).map(&method(:from_ffi_array_repr))
        end
      end

      def self.decrement_ref_count!(pointer)
        # Do nothing
      end

      # Define a new primitive type
      # Primitive types are stored by value
      # and efficiently copied using native FFI types
      # They are written directly into the memory of a container type
      #  (No indirection)
      def self.build(
        typename = nil,
        ffi_type: :uint8,
        memsize: FFI.type_size(ffi_type),
        convert_if: [],
        error: nil,
        ffi_primitive: false,
        superclass: Primitive,
        &block
      )
        Class.new(superclass) do
          %w[typename ffi_type memsize convert_if error ffi_primitive].each do |name|
            define_singleton_method(name) { binding.local_variable_get("#{name}") }
            define_method(name) { binding.local_variable_get("#{name}") }
          end

          class_eval(&block) if block_given?

          # Primitives are stored directly in memory as a raw numeric value
          def self.to_ffi_repr(value)
            new(value).inner_value
          end

          def self.refsize
            memsize
          end

          # Primiives are anonymous (Shouldn't be subclassed)
          def self.anonymous?
            true
          end

          def self.copy_to!(rbval, memory:)
            memory.send("write_#{self.ffi_type}", to_ffi_repr(rbval))
          end

          def self.primitive?
            true
          end

          def self.inspect
            inspect_name
          end

          def memory
            @value
          end

          def self.crystal_supertype
            "CrystalRuby::Types::Primitive"
          end
        end
      end
    end
  end
end

require_relative "primitive_types/time"
require_relative "primitive_types/symbol"
require_relative "primitive_types/numbers"
require_relative "primitive_types/nil"
require_relative "primitive_types/bool"
