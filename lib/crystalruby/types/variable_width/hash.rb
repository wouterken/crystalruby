# frozen_string_literal: true

module CrystalRuby::Types
  Hash = VariableWidth.build(error: "Hash type must have 2 type parameters. E.g. Hash(Float64, String)")

  def self.Hash(key_type, value_type)
    VariableWidth.build(:Hash, inner_types: [key_type, value_type], convert_if: [Root::Hash], superclass: Hash) do
      include Enumerable

      def_delegators :@class, :value_type, :key_type

      # Implement the Enumerable interface
      # Helps this object to act like a true Hash
      def each
        if block_given?
          size.times { |i| yield key_for_index(i), value_for_index(i) }
        else
          to_enum(:each)
        end
      end

      def keys
        each.map { |k, _| k }
      end

      def values
        each.map { |_, v| v }
      end

      def self.key_type
        inner_types.first
      end

      def self.value_type
        inner_types.last
      end

      # We only accept Hash-like values, from which all elements
      # can successfully be cast to our inner types
      def self.cast!(value)
        unless (value.is_a?(Hash) || value.is_a?(Root::Hash)) && value.keys.all?(&key_type.method(:valid_cast?)) && value.values.all?(&value_type.method(:valid_cast?))
          raise CrystalRuby::InvalidCastError, "Cannot cast #{value} to #{inspect}"
        end

        [[key_type, value.keys], [value_type, value.values]].map do |type, values|
          if type.primitive?
            values.map(&type.method(:to_ffi_repr))
          else
            values
          end
        end
      end

      def self.copy_to!((keys, values), memory:)
        data_pointer = malloc(values.size * (key_type.refsize + value_type.refsize))

        memory[size_offset].write_uint32(values.size)
        memory[data_offset].write_pointer(data_pointer)

        [
          [key_type, data_pointer, keys],
          [value_type, data_pointer[values.length * key_type.refsize], values]
        ].each do |type, pointer, list|
          if type.primitive?
            pointer.send("put_array_of_#{type.ffi_type}", 0, list)
          else
            list.each_with_index do |val, i|
              type.write_single(pointer[i * type.refsize], val)
            end
          end
        end
      end

      def index_for_key(key)
        size.times { |i| return i if key_for_index(i) == key }
        nil
      end

      def key_for_index(index)
        key_type.fetch_single(data_pointer[index * key_type.refsize])
      end

      def value_for_index(index)
        value_type.fetch_single(data_pointer[key_type.refsize * size + index * value_type.refsize])
      end

      def self.each_child_address(pointer)
        size = pointer[size_offset].read_int32
        pointer = pointer[data_offset].read_pointer
        size.times do |i|
          yield key_type, pointer[i * key_type.refsize]
          yield value_type, pointer[size * key_type.refsize + i * value_type.refsize]
        end
      end

      def [](key)
        return nil unless index = index_for_key(key)

        value_for_index(index)
      end

      def []=(key, value)
        if index = index_for_key(key)
          value_type.write_single(data_pointer[key_type.refsize * size + index * value_type.refsize], value)
        else
          method_missing(:[]=, key, value)
        end
      end

      def value(native: false)
        keys = key_type.fetch_multi(data_pointer, size, native: native)
        values = value_type.fetch_multi(data_pointer[key_type.refsize * size], size, native: native)
        keys.zip(values).to_h
      end
    end
  end
end
