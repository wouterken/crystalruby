class <%= base_crystal_class_name %> < CrystalRuby::Types::Primitive

  def initialize(value : ::Symbol)
    @value = 0.to_u32
    self.value = value
  end

  def initialize(value : UInt32)
    @value = value
  end

  def initialize(ptr : Pointer(::UInt8))
    initialize(ptr.as(Pointer(::UInt32))[0])
  end

  def ==(other : ::Symbol)
    value == other
  end

  def value=(value : ::Symbol)
    case value
    <% allowed_values.each_with_index do |v, i| %>
    when :<%= v %> then @value = <%= i %>.to_u32
    <% end %>
    else raise "Symbol must be one of <%= allowed_values %>. Got #{value}"
    end
  end

  def value : ::Symbol
    case @value
    <% allowed_values.each_with_index do |v, i| %>
    when <%= i %> then :<%= v %>
    <% end %>
    else raise "Symbol must be one of <%= allowed_values %>. Got #{value}"
    end
  end

  def self.copy_to!(value : ::Symbol, ptr : Pointer(::UInt8))
    ptr.as(Pointer(::UInt32))[0] = new(value).return_value
  end

  def self.memsize
    <%= memsize %>
  end

  def self.write_single(pointer : Pointer(::UInt8), value)
    as_uint32 = case value
    <% allowed_values.each_with_index do |v, i| %>
    when :<%= v %> then <%= i %>.to_u32
    <% end %>
    else raise "Symbol must be one of <%= allowed_values %>. Got #{value}"
    end
    pointer.as(Pointer(::UInt32)).value = as_uint32
  end
end
