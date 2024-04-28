class <%= base_crystal_class_name %> < CrystalRuby::Types::Primitive

  def initialize(value : ::Bool)
    @value = value ? 1_u8 : 0_u8
  end

  def initialize(ptr : Pointer(::UInt8))
    @value = ptr[0]
  end

  def initialize(value : UInt8)
    @value = value
  end

  def value=(value : ::Bool)
    @value = value ? 1_u8 : 0_u8
  end

  def value : <%= native_type_expr %>
    @value == 1_u8
  end

  def ==(other : ::Bool)
    value == other
  end

  def self.memsize
    <%= memsize %>
  end

  def self.write_single(pointer : Pointer(::UInt8), value)
    pointer.as(Pointer(::UInt8)).value = value ? 1_u8 : 0_u8
  end
end
