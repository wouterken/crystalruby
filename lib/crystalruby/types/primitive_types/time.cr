class <%= base_crystal_class_name %> < CrystalRuby::Types::Primitive

  def initialize(time : ::Time)
    @value = time.to_unix_ns / 1000_000_000.0
  end

  def initialize(ptr : Pointer(::UInt8))
    @value = ptr.as(Pointer(::Float64)).value
  end

  def initialize(@value : ::Float64)
  end

  def ==(other : ::Time)
    value == other
  end

  def value=(time : ::Time)
    @value = time.to_unix_ns / 1000_000_000.0
  end

  def value : ::Time
    ::Time.unix_ns((@value * 1000_000_000).to_i128)
  end

  def self.memsize
    <%= memsize %>
  end


  def self.write_single(pointer : Pointer(::UInt8), time)
    pointer.as(Pointer(::Float64)).value = time.to_unix_ns / 1000_000_000.0
  end

end
