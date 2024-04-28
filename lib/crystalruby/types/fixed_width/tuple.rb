# frozen_string_literal: true

module CrystalRuby::Types
  Tuple = FixedWidth.build(
    :Tuple,
    error: "Tuple type must contain one or more types E.g. Tuple(Int32, String)"
  )

  def self.Tuple(*types)
    FixedWidth.build(:Tuple, inner_types: types, convert_if: [Root::Array], superclass: Tuple) do
      @data_offset = 4

      # We only accept List-like values, which have all of the required keys
      # and values of the correct type
      # can successfully be cast to our inner types
      def self.cast!(value)
        unless (value.is_a?(Array) || value.is_a?(Tuple) || value.is_a?(Root::Array)) && value.zip(inner_types).each do |v, t|
                 t && t.valid_cast?(v)
               end && value.length == inner_types.length
          raise CrystalRuby::InvalidCastError, "Cannot cast #{value} to #{inspect}"
        end

        value
      end

      def self.copy_to!(values, memory:)
        data_pointer = malloc(memsize)

        memory[data_offset].write_pointer(data_pointer)

        inner_types.each.reduce(0) do |offset, type|
          type.write_single(data_pointer[offset], values.shift)
          offset + type.refsize
        end
      end

      def self.each_child_address(pointer)
        data_pointer = pointer[data_offset].read_pointer
        inner_types.each do |type|
          yield type, data_pointer
          data_pointer += type.refsize
        end
      end

      def self.memsize
        inner_types.map(&:refsize).sum
      end

      def size
        inner_types.size
      end

      def checked_offset!(index, size)
        raise "Index out of bounds: #{index} >= #{size}" if index >= size

        if index < 0
          raise "Index out of bounds: #{index} < -#{size}" if index < -size

          index += size
        end
        self.class.offset_for(index)
      end

      def self.offset_for(index)
        inner_types[0...index].map(&:refsize).sum
      end

      # Return the element at the given index.
      # This will automatically increment
      # the reference count if not a primitive type.
      def [](index)
        inner_types[index].fetch_single(data_pointer[checked_offset!(index, size)])
      end

      # Overwrite the element at the given index
      # The replaced element will have
      # its reference count decremented.
      def []=(index, value)
        inner_types[index].write_single(data_pointer[checked_offset!(index, size)], value)
      end

      def value(native: false)
        ptr = data_pointer
        inner_types.map do |type|
          result = type.fetch_single(ptr, native: native)
          ptr += type.refsize
          result
        end
      end
    end
  end
end
