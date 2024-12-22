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
      # Strings in Crystal are UTF-8 encoded by default
      data_pointer.read_string(size).force_encoding("UTF-8")
    end
  end
end
