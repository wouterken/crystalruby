module CrystalRuby
  module Types
    class VariableWidth < FixedWidth

      def self.size_offset
        4
      end

      def self.data_offset
        8
      end

      def self.memsize
        8
      end

      def variable_width?
        true
      end

    end
  end
end
