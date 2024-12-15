# frozen_string_literal: true

module CrystalRuby::Types
  TaggedUnion = Class.new(Type) { @error = "Union type must be instantiated from one or more concrete types" }

  def self.TaggedUnion(*union_types)
    Class.new(FixedWidth) do
      # We only accept List-like values, which have all of the required keys
      # and values of the correct type
      # can successfully be cast to our inner types
      def self.cast!(value)
        casteable_type_index = union_types.find_index do |type, _index|
          next false unless type.valid_cast?(value)

          type.cast!(value)
          next true
        rescue StandardError
          nil
        end
        unless casteable_type_index
          raise CrystalRuby::InvalidCastError,
                "Cannot cast #{value}:#{value.class} to #{inspect}"
        end

        [casteable_type_index, value]
      end

      def value(native: false)
        type = self.class.union_types[data_pointer.read_uint8]
        type.fetch_single(data_pointer[1], native: native)
      end

      def nil?
        value.nil?
      end

      def ==(other)
        value == other
      end

      def self.copy_to!((type_index, value), memory:)
        memory[data_offset].write_int8(type_index)
        union_types[type_index].write_single(memory[data_offset + 1], value)
      end

      def data_pointer
        memory[data_offset]
      end

      def self.each_child_address(pointer)
        pointer += data_offset
        type = self.union_types[pointer.read_uint8]
        yield type, pointer[1]
      end

      def self.inner_types
        union_types
      end

      define_singleton_method(:memsize) do
        union_types.map(&:refsize).max + 1
      end

      def self.refsize
        8
      end

      def self.typename
        "TaggedUnion"
      end

      define_singleton_method(:union_types) do
        union_types
      end

      define_singleton_method(:valid?) do
        union_types.all?(&:valid?)
      end

      define_singleton_method(:error) do
        union_types.map(&:error).join(", ") if union_types.any?(&:error)
      end

      define_singleton_method(:inspect) do
        if anonymous?
          union_types.map(&:inspect).join(" | ")
        else
          crystal_class_name
        end
      end

      define_singleton_method(:native_type_expr) do
        union_types.map(&:native_type_expr).join(" | ")
      end

      define_singleton_method(:named_type_expr) do
        union_types.map(&:named_type_expr).join(" | ")
      end

      define_singleton_method(:type_expr) do
        anonymous? ? native_type_expr : name
      end

      define_singleton_method(:data_offset) do
        4
      end

      define_singleton_method(:valid_cast?) do |raw|
        union_types.any? { |type| type.valid_cast?(raw) }
      end
    end
  end
end
