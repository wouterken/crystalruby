module CrystalRuby
  module Types
    # For a fixed width type, we allocate a single block block of memory of the form
    # [ref_count (uint32), data(uint8*)]
    class FixedWidth < Type

      # We can instantiate it with a Value (for a new object)
      # or a Pointer (for a copy of an existing object)
      macro inherited
        def initialize(@memory : Pointer(::UInt8))
          increment_ref_count!
        end
      end

      def finalize
        self.class.decrement_ref_count!(@memory)
      end

      def increment_ref_count!
        self.class.increment_ref_count!(@memory)
      end

      def self.increment_ref_count!(memory, by=1)
        as_int32_ptr = memory.as(Pointer(::UInt32))
        synchronize{ as_int32_ptr[0] += by }
      end

      def self.decrement_ref_count!(memory, by=1)
        as_int32_ptr = memory.as(Pointer(::UInt32))
        synchronize{ as_int32_ptr[0] -= by }
        free!(memory) if as_int32_ptr[0] == 0
      end

      def self.refsize
        8
      end

      def self.new_decr(arg)
        new_value = self.new(arg)
        self.decrement_ref_count!(new_value.memory)
        new_value
      end

      def native_decr
        self.class.decrement_ref_count!(@memory)
        native
      end


      def self.free!(memory)
        # Decrease ref counts for any data we are pointing to
        # Also responsible for freeing internal memory if ref count reaches zero
        decr_inner_ref_counts!(memory)
        # # Free slot memory
        free(memory)
      end

      def self.decr_inner_ref_counts!(pointer)
        self.each_child_address(pointer) do |child_type, child_address|
          child_type.decrement_ref_count!(child_address.read_pointer)
        end
        # Free data block, if we're a variable with type.
        as_pointer_ref = (pointer+data_offset).as(Pointer(Pointer(::UInt8)))
        free(as_pointer_ref[0]) if variable_width?
      end

      def self.variable_width?
        false
      end

      # Ref count is always the first UInt32 in the memory block
      def ref_count
        memory.as(Pointer(::UInt32))[0]
      end

      def ref_count=(val)
        memory.as(Pointer(::UInt32))[0] = value
      end

      # When we pass to Ruby, we increment the ref count
      # for Ruby to decrement again once it receives.
      def return_value
        FixedWidth.increment_ref_count!(memory)
        memory
      end

      # Data pointer follows the ref count (and size for variable width types)
      # In the case of variable width types the data pointer points to the start of a separate data block
      # So this method is overridden inside variable_width.rb to resolve this pointer.
      def data_pointer : Pointer(UInt8)
        (memory + data_offset)
      end

      # Create a brand new copy of this object
      def deep_dup
        self.class.new(value)
      end

      # Create a new reference to this object.
      def dup
        self.class.new(@memory)
      end

      def address
        memory.address
      end

      def data_offset
        self.class.data_offset
      end

      def memsize
        self.class.memsize
      end

      def size_offset
        self.class.size_offset
      end

      def self.size_offset
        4
      end

      def self.data_offset
        4
      end

      # Read a value of this type from the
      # contained pointer at a given index
      def self.fetch_single(pointer : Pointer(::UInt8))
        value_pointer = pointer.as(Pointer(Pointer(::UInt8)))
        new(value_pointer.value)
      end

      # Write a data type into a pointer at a given index
      # (Type can be a byte-array, pointer or numeric type
      #
      # )
      def self.write_single(pointer, value)
        value_pointer = pointer.as(Pointer(Pointer(::UInt8)))
        if !value_pointer[0].null?
          decrement_ref_count!(value_pointer[0])
        end
        memory = malloc(self.data_offset + self.memsize)

        self.copy_to!(value, memory)
        value_pointer.value = memory
        increment_ref_count!(memory)
      end

      # Fetch an array of a given data type from a list pointer
      # (Type can be a byte-array, pointer or numeric type)

    end
  end
end
