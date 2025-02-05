module CrystalRuby
  module Types
    # A variable with type operates much like a fixed width type, but
    # it writes a size and a pointer to the type memory instead of the data itself.
    # When we decrement our internal ref count we need to resolve the pointer.
    # The layout is a tiny bit different (data begins at byte 8 to allow room for size uint32 at byte 4)
    class VariableWidth < FixedWidth
      def self.variable_width?
        true
      end

      def self.crystal_supertype
        "CrystalRuby::Types::VariableWidth"
      end

      def self.build(
        typename = nil,
        error: nil,
        inner_types: nil,
        inner_keys: nil,
        ffi_type: :pointer,
        ffi_primitive: false,
        size_offset: 4,
        data_offset: 8,
        memsize: FFI.type_size(ffi_type),
        refsize: 8,
        convert_if: [],
        superclass: VariableWidth,
        &block
      )
        inner_types&.each(&Type.method(:validate!))

        Class.new(superclass) do
          bind_local_vars!(
            %i[typename error inner_types inner_keys ffi_type memsize convert_if data_offset size_offset
               refsize ffi_primitive], binding
          )
          class_eval(&block) if block_given?
        end
      end
    end
  end
end

require_relative "variable_width/string"
require_relative "variable_width/array"
require_relative "variable_width/hash"
