module CrystalRuby::Types
  %i[UInt8 UInt16 UInt32 UInt64 Int8 Int16 Int32 Int64 Float32 Float64].each do |type_name|
    ffi_type = CrystalRuby::Typemaps::FFI_TYPE_MAP.fetch(type_name.to_s)
    const_set(type_name, Primitive.build(type_name, convert_if: [::Numeric], ffi_type: ffi_type) do
      def value=(val)
        raise "Expected a numeric value, got #{val}" unless val.is_a?(::Numeric)

        super(typename.to_s.start_with?("Float") ? val.to_f : val.to_i)
      end

      def value(native: false)
        @value
      end

      def self.from_ffi_array_repr(value)
        value
      end

      def self.numeric?
        true
      end

      def self.template_name
        "Numbers"
      end
    end)
  end
end
