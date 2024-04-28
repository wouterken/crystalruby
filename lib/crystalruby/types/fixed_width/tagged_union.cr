class <%= base_crystal_class_name %> < CrystalRuby::Types::FixedWidth

  def initialize(value : <%= native_type_expr %>)
    @memory = malloc(data_offset + <%= memsize %>_u64)
    self.value = value
    increment_ref_count!
  end

  def value=(value : <%= native_type_expr %>)
    self.class.copy_to!(value, @memory)
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def value
    data_pointer = @memory + data_offset
    case data_pointer.value
    <% union_types.each_with_index do |type, index| %>
      when <%= index %>
      <%= type.crystal_class_name %>.fetch_single(data_pointer+1)
    <% end %>
    else raise "Invalid union type #{data_pointer.value}"
    end
  end

  def native
    data_pointer = @memory + data_offset
    case data_pointer.value
    <% union_types.each_with_index do |type, index| %>
      when <%= index %>
      <%= type.crystal_class_name %>.fetch_single(data_pointer+1).native
    <% end %>
    else raise "Invalid union type #{data_pointer.value}"
    end
  end

  def self.copy_to!(value : <%= native_type_expr %>, ptr : Pointer(::UInt8))
    data_pointer = ptr + data_offset
    case value
    <% union_types.each_with_index do |type, index| %>
      when <%= type.native_type_expr %>
        data_pointer[0] = <%= index %>
        <%= type.crystal_class_name %>.write_single(data_pointer + 1, value)
    <% end %>
    end
  end

  def self.memsize
    <%= memsize %>
  end
end
