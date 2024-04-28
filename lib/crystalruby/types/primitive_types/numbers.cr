class <%= base_crystal_class_name %> < CrystalRuby::Types::Primitive

  def initialize(value : <%= native_type_expr %>)
    @value = value
  end

  def initialize(ptr : Pointer(::UInt8))
    @value = ptr.as(Pointer( <%= native_type_expr %>))[0]
  end

  def value
    @value
  end

  def ==(other : <%= native_type_expr %>)
    value == other
  end

  def self.memsize
    <%= memsize %>
  end

  def value=(value : <%= native_type_expr %>)
    @value = value
  end

  def self.copy_to!(value : <%= native_type_expr %>, ptr : Pointer(::UInt8))
    ptr.as(Pointer( <%= native_type_expr %>))[0] = value
  end

  # Write a data type into a pointer at a given index
  # (Type can be a byte-array, pointer or numeric type)
  def self.write_single(pointer : Pointer(::UInt8), value)
    pointer.as(Pointer( <%= native_type_expr %>)).value = value
  end

end
