# frozen_string_literal: true

module CrystalRuby::Types
  NamedTuple = FixedWidth.build(error: "NamedTuple type must contain one or more symbol -> type pairs. E.g. NamedTuple(hello: Int32, world: String)")

  def self.NamedTuple(types_hash)
    raise "NamedTuple must be instantiated with a hash" unless types_hash.is_a?(Root::Hash)

    types_hash.keys.each do |key|
      raise "NamedTuple keys must be symbols" unless key.is_a?(Root::Symbol) || key.respond_to?(:to_sym)
    end
    keys = types_hash.keys.map(&:to_sym)
    value_types = types_hash.values

    FixedWidth.build(:NamedTuple, ffi_type: :pointer, inner_types: value_types, inner_keys: keys,
                                  convert_if: [Root::Hash]) do
      @data_offset = 4

      # We only accept Hash-like values, which have all of the required keys
      # and values of the correct type
      # can successfully be cast to our inner types
      def self.cast!(value)
        value = value.transform_keys(&:to_sym)
        unless value.is_a?(Hash) || value.is_a?(Root::Hash) && inner_keys.each_with_index.all? do |k, i|
                 value.key?(k) && inner_types[i].valid_cast?(value[k])
               end
          raise CrystalRuby::InvalidCastError, "Cannot cast #{value} to #{inspect}"
        end

        inner_keys.map { |k| value[k] }
      end

      def self.copy_to!(values, memory:)
        data_pointer = malloc(memsize)

        memory[data_offset].write_pointer(data_pointer)

        inner_types.each.reduce(0) do |offset, type|
          type.write_single(data_pointer[offset], values.shift)
          offset + type.refsize
        end
      end

      def self.memsize
        inner_types.map(&:refsize).sum
      end

      def self.each_child_address(pointer)
        data_pointer = pointer[data_offset].read_pointer
        inner_types.each do |type|
          yield type, data_pointer
          data_pointer += type.refsize
        end
      end

      def self.offset_for(key)
        inner_types[0...inner_keys.index(key)].map(&:refsize).sum
      end

      def value(native: false)
        ptr = data_pointer
        inner_keys.zip(inner_types.map do |type|
          result = type.fetch_single(ptr, native: native)
          ptr += type.refsize
          result
        end).to_h
      end

      inner_keys.each.with_index do |key, index|
        type = inner_types[index]
        offset = offset_for(key)
        unless method_defined?(key)
          define_method(key) do
            type.fetch_single(data_pointer[offset])
          end
        end

        unless method_defined?("#{key}=")
          define_method("#{key}=") do |value|
            type.write_single(data_pointer[offset], value)
          end
        end
      end
    end
  end
end
