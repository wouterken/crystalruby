class <%= base_crystal_class_name %> < CrystalRuby::Types::FixedWidth

  def initialize(tuple : ::Tuple(<%= inner_types.map(&:native_type_expr).join(',') %>))
    @memory = malloc(data_offset + 8)
    self.value = tuple
    increment_ref_count!
  end

  def data_pointer
    Pointer(::UInt8).new((@memory + data_offset).as(Pointer(::UInt64)).value)
  end

  def [](index : Int)
    index += size if index < 0
    <% offset = 0 %>
    <% inner_types.each_with_index do |type, i| %>
      <% offset += type.refsize %>
      return <%= type.crystal_class_name %>.fetch_single(data_pointer + <%= offset - type.refsize %>) if <%= i %> == index
    <% end %>
  end

  <% inner_types.each_with_index.group_by{|t,i| t.native_type_expr }.each do |(native_type_expr, types_width_index)| %>
  def []=(index : Int, value : <%= native_type_expr %>)
    index += size if index < 0
    <% types_width_index.each do |type, i| %>
      return <%= type.crystal_class_name %>.write_single(data_pointer + <%= offset_for(i) %>, value) if <%= i %> == index
    <% end %>
    raise ArgumentError.new("Index out of bounds")
  end
  <% end %>

  def ==(other : ::Tuple(<%= inner_types.map(&:native_type_expr).join(',') %>))
    value == other
  end

  def value=(tuple : ::Tuple(<%= inner_types.map(&:native_type_expr).join(',') %>))
    self.class.copy_to!(tuple, @memory)
  end

  def self.copy_to!(tuple : ::Tuple(<%= inner_types.map(&:native_type_expr).join(',') %>), memory : Pointer(::UInt8))

    data_pointer = malloc(self.memsize)
    address = data_pointer.address

    <% inner_types.each_with_index do |type, i| %>
      <%= type.crystal_class_name %>.write_single(data_pointer, tuple[<%= i %>])
      data_pointer += <%= type.refsize %>
    <% end %>

    (memory+data_offset).as(Pointer(::UInt64)).value = address
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def value : ::Tuple(<%= inner_types.map(&:native_type_expr).join(',') %>)
    address = data_pointer
    <% inner_types.each_with_index do |type, i| %>
      v<%= i %> = <%= type.crystal_class_name %>.fetch_single(address)
      address += <%= type.refsize %>
    <% end %>
    ::Tuple.new(<%= inner_types.map.with_index { |_, i| "v#{i}" }.join(", ") %>)
  end

  def native : ::Tuple(<%= inner_types.map(&:native_type_expr).join(',') %>)
    address = data_pointer
    <% inner_types.each_with_index do |type, i| %>
      v<%= i %> = <%= type.crystal_class_name %>.fetch_single(address).native
      address += <%= type.refsize %>
    <% end %>
    ::Tuple.new(<%= inner_types.map.with_index { |_, i| "v#{i}" }.join(", ") %>)
  end

  def self.memsize
    <%= memsize %>
  end

  def self.refsize
    <%= refsize %>
  end
end
