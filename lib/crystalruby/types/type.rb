module CrystalRuby
  module Types
    class Type
      attr_accessor :name, :error, :inner_types, :inner_keys, :accept_if, :convert

      def initialize(name, error: nil, inner_types: nil, inner_keys: nil, accept_if: [], &convert)
        self.name = name
        self.error = error
        self.inner_types = inner_types
        self.inner_keys = inner_keys
        self.accept_if = accept_if
        self.convert = convert
      end

      def union_types
        [self]
      end

      def valid?
        !error
      end

      def |(other)
        raise "Cannot union non-crystal type #{other}" unless other.is_a?(Type) || (
          other.is_a?(Class) && other.ancestors.include?(Typedef)
        )

        UnionType.new(*union_types, *other.union_types)
      end

      def type_expr
        inspect
      end

      def inspect
        if !inner_types
          name
        elsif !inner_keys
          "#{name}(#{inner_types.map(&:inspect).join(", ")})"
        else
          "#{name}(#{inner_keys.zip(inner_types).map { |k, v| "#{k}: #{v.inspect}" }.join(", ")})"
        end
      end

      def interprets?(raw)
        accept_if.any? { |type| raw.is_a?(type) }
      end

      def interpret!(raw)
        if interprets?(raw)
          convert ? convert.call(raw) : raw
        else
          raise "Invalid deserialized value #{raw} for type #{inspect}"
        end
      end

      def self.validate!(type)
        unless type.is_a?(Types::Type) || (type.is_a?(Class) && type.ancestors.include?(Types::Typedef))
          raise "Result #{type} is not a valid CrystalRuby type"
        end

        raise "Invalid type: #{type.error}" unless type.valid?
      end
    end
  end
end
