class <%= base_crystal_class_name %> < CrystalRuby::Types::Primitive

  property value : ::Nil = nil

  def initialize(nilval : ::Nil)
  end

  def initialize(ptr : Pointer(::UInt8))
  end

  def initialize(raw : UInt8)
  end

  def value : ::Nil
    nil
  end

  def ==(other : ::Nil)
    value.nil?
  end

  def value=(val : ::Nil)
  end

  def self.memsize
    0
  end

  def return_value
    0_u8
  end

  def self.write_single(pointer : Pointer(::UInt8), value)
  end
end
