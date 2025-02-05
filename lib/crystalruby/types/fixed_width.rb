module CrystalRuby
  module Types
    # For a fixed width type, we allocate a single block block of memory of the form
    # [ref_count (uint32), data(uint8*)]
    class FixedWidth < Type
      # We can instantiate it with a Value (for a new object)
      # or a Pointer (for a copy of an existing object)
      def initialize(rbval)
        super
        case rbval
        when FFI::Pointer then allocate_new_from_reference!(rbval)
        else allocate_new_from_value!(rbval)
        end
        self.class.increment_ref_count!(memory)
        ObjectSpace.define_finalizer(self, self.class.finalize(memory, self.class))
        Allocator.gc_hint!(total_memsize)
      end

      def self.finalize(memory, type)
        lambda do |_|
          decrement_ref_count!(memory)
        end
      end

      def allocate_new_from_value!(rbval)
        # New block of memory, to hold our object.
        # For variable with, this is 2x UInt32 for ref count and size, plus a data pointer (8 bytes)
        # Layout:
        # - ref_count (4 bytes)
        # - size (4 bytes)
        # - data (8 bytes)
        #
        # For fixed the data is inline
        # Layout:
        # - ref_count (4 bytes)
        # - size (0 bytes) (No size for fixed width types)
        # - data (memsize bytes)
        self.memory = malloc(refsize + data_offset)
        self.value = rbval
      end

      def allocate_new_from_reference!(memory)
        # When we point to an existing block of memory, we don't need to allocate anything.
        # This memory should be to a single, separately allocated block of the above size.
        # When this type is contained within another type, it should be as a pointer to this block (not the contents of the block itself).
        self.memory = memory
      end

      # Each type should be convertible to an FFI representation. (I.e. how is a value or reference to this value stored
      # within e.g. an Array, Hash, Tuple or any other containing type).
      # For both fixed and variable types these are simply stored within
      # the containing type as a pointer to the memory block.
      # We return the pointer to this memory here.
      def self.to_ffi_repr(value)
        to_store = new(value)
        increment_ref_count!(to_store.memory)
        to_store.memory
      end

      # Read a value of this type from the
      # contained pointer at a given index
      def self.fetch_single(pointer, native: false)
        # Nothing to fetch for Nils
        return if memsize.zero?

        value_pointer = pointer.read_pointer
        native ? new(value_pointer).native : new(value_pointer)
      end

      # Write a data type into a pointer at a given index
      # (Type can be a byte-array, pointer or numeric type
      #
      # )
      def self.write_single(pointer, value)
        # Dont need to write nils
        return if memsize.zero?

        decrement_ref_count!(pointer.read_pointer) unless pointer.read_pointer.null?
        memory = malloc(refsize + data_offset)
        copy_to!(cast!(value), memory: memory)
        increment_ref_count!(memory)
        pointer.write_pointer(memory)
      end

      # Fetch an array of a given data type from a list pointer
      # (Type can be a byte-array, pointer or numeric type)
      def self.fetch_multi(pointer, size, native: false)
        size.times.map { |i| fetch_single(pointer[i * refsize], native: native) }
      end

      def self.increment_ref_count!(memory, by = 1)
        synchronize { memory.write_int32(memory.read_int32 + by) }
      end

      def self.decrement_ref_count!(memory, by = 1)
        synchronize { memory.write_int32(memory.read_int32 - by) }
        return unless memory.read_int32.zero?

        free!(memory)
      end

      def self.free!(memory)
        # Decrease ref counts for any data we are pointing to
        # Also responsible for freeing internal memory if ref count reaches zero
        decr_inner_ref_counts!(memory)

        # # Free slot memory
        free(memory)
      end

      def self.decr_inner_ref_counts!(pointer)
        each_child_address(pointer) do |child_type, child_address|
          child_type.decrement_ref_count!(child_address.read_pointer) if child_type.fixed_width?
        end
        # Free data block, if we're a variable width type.
        return unless variable_width?

        free(pointer[data_offset].read_pointer)
      end

      # Ref count is always the first Int32 in the memory block
      def ref_count
        memory.read_uint32
      end

      def ref_count=(val)
        memory.write_int32(val)
      end

      # Data pointer follows the ref count (and size for variable width types)
      # In the case of variable width types the data pointer points to the start of a separate data block
      # So this method is overridden inside variable_width.rb to resolve this pointer.
      def data_pointer
        memory[data_offset].read_pointer
      end

      def size
        memory[size_offset].read_int32
      end

      def total_memsize
        memsize + refsize + size
      end

      def address
        @memory.address
      end

      def self.crystal_supertype
        "CrystalRuby::Types::FixedWidth"
      end

      def self.crystal_type
        "Pointer(::UInt8)"
      end

      # If we are fixed with,
      # The memory we allocate a single block of memory, if not already given.
      # Within this block of memory, we copy our contents directly.
      #
      # If we are variable width, we allocate a small block of memory for the pointer only
      # and allocate a separate block of memory for the data.
      # We store the pointer to the data in the memory block.

      def value=(value)
        # If we're already pointing at something
        # Decrement the ref counts of anything we're pointing at
        value = cast!(value)

        self.class.decr_inner_ref_counts!(memory) if ref_count > 0
        self.class.copy_to!(value, memory: memory)
      end

      # Build a new FixedWith subtype
      # Layout varies according to the sizes of internal types
      def self.build(
        typename = nil,
        error: nil,
        inner_types: nil,
        inner_keys: nil,
        ffi_type: :pointer,
        memsize: FFI.type_size(ffi_type),
        refsize: 8,
        convert_if: [],
        superclass: FixedWidth,
        size_offset: 4,
        data_offset: 4,
        ffi_primitive: false,
        &block
      )
        inner_types&.each(&Type.method(:validate!))

        Class.new(superclass) do
          bind_local_vars!(
            %i[typename error inner_types inner_keys ffi_type memsize convert_if size_offset data_offset
               refsize ffi_primitive], binding
          )
          class_eval(&block) if block_given?

          def self.fixed_width?
            true
          end
        end
      end
    end
  end
end
require_relative "fixed_width/proc"
require_relative "fixed_width/named_tuple"
require_relative "fixed_width/tuple"
require_relative "fixed_width/tagged_union"
