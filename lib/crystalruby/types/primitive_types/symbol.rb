module CrystalRuby::Types
  Symbol = Primitive.build(
    error: "Symbol CrystalRuby types should indicate a list of possible values shared between Crystal and Ruby. "\
    "E.g. Symbol(:green, :blue, :orange). If this list is not known at compile time, you should use a String instead."
  )

  def self.Symbol(*allowed_values)
    raise "Symbol must have at least one value" if allowed_values.empty?

    allowed_values.flatten!
    raise "Symbol allowed values must all be symbols" unless allowed_values.all? { |v| v.is_a?(::Symbol) }

    Primitive.build(:Symbol, ffi_type: :uint32, convert_if: [Root::String, Root::Symbol], memsize: 4) do
      bind_local_vars!(%i[allowed_values], binding)
      define_method(:value=) do |val|
        val = allowed_values[val] if val.is_a?(::Integer) && val >= 0 && val < allowed_values.size
        raise "Symbol must be one of #{allowed_values}" unless allowed_values.include?(val)

        super(allowed_values.index(val))
      end

      define_singleton_method(:valid_cast?) do |raw|
        super(raw) && allowed_values.include?(raw)
      end

      define_method(:value) do |native: false|
        allowed_values[super()]
      end

      define_singleton_method(:type_digest) do
        Digest::MD5.hexdigest(native_type_expr.to_s + allowed_values.map(&:to_s).join(","))
      end

      def self.ffi_primitive_type
        nil
      end
    end
  end
end
