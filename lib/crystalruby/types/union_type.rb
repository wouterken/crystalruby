module CrystalRuby
  module Types
    class UnionType < Type
      attr_accessor :name, :union_types

      def initialize(*union_types)
        self.name = "UnionType"
        self.union_types = union_types
      end

      def valid?
        union_types.all?(&:valid?)
      end

      def error
        union_types.map(&:error).join(", ")
      end

      def inspect
        union_types.map(&:inspect).join(" | ")
      end

      def interprets?(raw)
        union_types.any? { |type| type.interprets?(raw) }
      end

      def interpret!(raw)
        union_types.each do |type|
          if type.interprets?(raw)
            return type.interpret!(raw)
          end
        end
        raise "Invalid deserialized value #{raw} for type #{inspect}"
      end
    end
  end
end
