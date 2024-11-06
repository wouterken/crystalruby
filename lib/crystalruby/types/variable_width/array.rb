# frozen_string_literal: true

module CrystalRuby::Types
  Array = VariableWidth.build(error: "Array type must have a type parameter. E.g. Array(Float64)")

  # An array-like, reference counted manually managed memory type.
  # Shareable between Crystal and Crystal.
  def self.Array(type)
    VariableWidth.build(:Array, inner_types: [type], convert_if: [Array, Root::Array], superclass: Array) do
      include Enumerable

      # Implement the Enumerable interface
      # Helps this object to act like an Array
      def each
        size.times { |i| yield self[i] }
      end

      # We only accept Array-like values, from which all elements
      # can successfully be cast to our inner type
      def self.cast!(value)
        unless value.is_a?(Array) || value.is_a?(Root::Array) && value.all?(&inner_type.method(:valid_cast?))
          raise CrystalRuby::InvalidCastError, "Cannot cast #{value} to #{inspect}"
        end

        if inner_type.primitive?
          value.map(&inner_type.method(:to_ffi_repr))
        else
          value
        end
      end

      def self.copy_to!(rbval, memory:)
        data_pointer = malloc(rbval.size * inner_type.refsize)

        memory[size_offset].write_uint32(rbval.size)
        memory[data_offset].write_pointer(data_pointer)

        if inner_type.primitive?
          data_pointer.send("put_array_of_#{inner_type.ffi_type}", 0, rbval)
        else
          rbval.each_with_index do |val, i|
            inner_type.write_single(data_pointer[i * refsize], val)
          end
        end
      end

      def self.each_child_address(pointer)
        size = pointer[size_offset].get_int32(0)
        pointer = pointer[data_offset].read_pointer
        size.times do |i|
          yield inner_type, pointer[i * inner_type.refsize]
        end
      end

      def checked_offset!(index, size)
        raise "Index out of bounds: #{index} >= #{size}" if index >= size

        if index < 0
          raise "Index out of bounds: #{index} < -#{size}" if index < -size

          index += size
        end
        index
      end

      # Return the element at the given index.
      # This will automatically increment
      # the reference count if not a primitive type.
      def [](index)
        inner_type.fetch_single(data_pointer[checked_offset!(index, size) * inner_type.refsize])
      end

      # Overwrite the element at the given index
      # The replaced element will have
      # its reference count decremented.
      def []=(index, value)
        inner_type.write_single(data_pointer[checked_offset!(index, size) * inner_type.refsize], value)
      end

      # Load values stored inside array type.
      # If it's a primitive type, we can quickly bulk load the values.
      # Otherwise we need toinstantiate new ref-checked instances.
      def value(native: false)
        inner_type.fetch_multi(data_pointer, size, native: native)
      end
    end
  end
end
