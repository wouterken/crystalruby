module CrystalRuby
  module Types
    class Primitive < Type
      def return_value
        @value
      end

      def native
        value
      end

      def self.fetch_single(pointer : Pointer(::UInt8))
        new(pointer)
      end

      def self.refsize
        self.memsize
      end
    end
  end
end
