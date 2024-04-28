module CrystalRuby::Types
  String = VariableWidth.build(:String, convert_if: [String, Root::String]) do
    def self.cast!(rbval)
      rbval.to_s
    end

    def self.copy_to!(rbval, memory:)
      data_pointer = malloc(rbval.bytesize)
      data_pointer.write_string(rbval)
      memory[size_offset].write_uint32(rbval.size)
      memory[data_offset].write_pointer(data_pointer)
    end

    def value(native: false)
      data_pointer.read_string(size)
    end
  end
end
