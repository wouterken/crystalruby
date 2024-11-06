class <%= base_crystal_class_name %> < CrystalRuby::Types::VariableWidth

  def initialize(string : ::String)
    @memory = malloc(data_offset + 8)
    self.value = string
    increment_ref_count!
  end

  def self.copy_to!(value : ::String, memory : Pointer(::UInt8))
    data_pointer = malloc(value.bytesize.to_u32).as(Pointer(::UInt8))
    data_pointer.copy_from(value.to_unsafe, value.bytesize)
    (memory+size_offset).as(Pointer(::UInt32)).value = value.bytesize.to_u32
    (memory+data_offset).as(Pointer(::UInt64)).value = data_pointer.address
  end

  def value=(string : ::String)
    if self.ref_count > 0
      self.class.decr_inner_ref_counts!(memory)
    end
    self.class.copy_to!(string, self.memory)
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def value : ::String
    char_ptr = (memory + data_offset).as(Pointer(Pointer(::UInt8)))
    size = (memory + size_offset).as(Pointer(::UInt32))
    ::String.new(char_ptr[0], size[0])
  end

  def native : ::String
    value
  end
end
