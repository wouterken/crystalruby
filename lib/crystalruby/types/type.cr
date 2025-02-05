module CrystalRuby
  module Types
    class Type
      property memory : Pointer(::UInt8) = Pointer(::UInt8).null

      macro method_missing(call)
        current_value = self.native
        current_hash = current_value.hash
        return_value = current_value.{{ call }}

        if current_hash != current_value.hash
          self.value = current_value
        end
        return_value
      end

      def to_s
        native.to_s
      end
      
      def self.new_decr(arg)
        self.new(arg)
      end

      def native_decr
        native
      end

      def synchronize
        CrystalRuby.synchronize do
          yield
        end
      end

      def self.synchronize
        yield
      end

      def variable_width?
        false
      end

      def return_value
        memory
      end

      def self.free(memory : Pointer(::UInt8))
        LibC.free(memory)
      end

      def self.malloc(size : Int) : Pointer(::UInt8)
        LibC.calloc(size, 1).as(Pointer(::UInt8))
      end

      def malloc(memsize)
        self.class.malloc(memsize)
      end

      def self.each_child_address(pointer : Pointer(::UInt8), &block : Pointer(::UInt8) -> Nil)
        # Do nothing
      end

      def self.fetch_multi!(pointer : Pointer(::UInt8), size)
        size.times.map { |i| fetch_single(pointer + i * refsize) }.to_a
      end

      def self.fetch_multi_native!(pointer : Pointer(::UInt8), size)
        size.times.map { |i| fetch_single(pointer + i * refsize).native }.to_a
      end
    end
  end
end
