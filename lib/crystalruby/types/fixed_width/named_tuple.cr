class <%= base_crystal_class_name %> < CrystalRuby::Types::FixedWidth

  def initialize(tuple : ::NamedTuple(<%= inner_keys.zip(inner_types).map{|k,v| "#{k}: #{v.native_type_expr}"}.join(',') %>))
    @memory = malloc(data_offset + 8)
    self.value = tuple
    increment_ref_count!
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def data_pointer
    Pointer(::UInt8).new((@memory + data_offset).as(::Pointer(UInt64)).value)
  end

  def [](key : Symbol | String)
    <% offset = 0 %>
    <% inner_types.each_with_index do |type, i| %>
      <% offset += type.refsize %>
      return <%= type.crystal_class_name %>.fetch_single(data_pointer + <%= offset - type.refsize %>).value if :<%= inner_keys[i] %> == key || key == "<%= inner_keys[i] %>"
    <% end %>
  end

  <% offset = 0 %>
  <% inner_types.each_with_index do |type, i| %>
    <% offset += type.refsize %>
    def <%= inner_keys[i] %>
      return <%= type.crystal_class_name %>.fetch_single(data_pointer + <%= offset - type.refsize %>)
    end

    def <%= inner_keys[i] %>=(value : <%= type.native_type_expr %>)
      return <%= type.crystal_class_name %>.write_single(data_pointer + <%= offset - type.refsize %>, value)
    end
  <% end %>



  def value=(tuple : ::NamedTuple(<%= inner_keys.zip(inner_types).map{|k,v| "#{k}: #{v.native_type_expr}"}.join(',') %>))
    self.class.copy_to!(tuple, @memory)
  end

  def self.copy_to!(tuple : ::NamedTuple(<%= inner_keys.zip(inner_types).map{|k,v| "#{k}: #{v.native_type_expr}"}.join(',') %>), memory : Pointer(::UInt8))
    data_pointer = malloc(self.memsize)
    address = data_pointer.address

    <% inner_types.each_with_index do |type, i| %>
      <%= type.crystal_class_name %>.write_single(data_pointer, tuple[:<%= inner_keys[i] %>])
      data_pointer += <%= type.refsize %>
    <% end %>

    (memory+data_offset).as(Pointer(::UInt64)).value = address
  end

  def value
    address = data_pointer
    <% inner_types.each_with_index do |type, i| %>
      v<%= i %> = <%= type.crystal_class_name %>.fetch_single(address)
      address += <%= type.refsize %>
    <% end %>
    ::NamedTuple.new(<%= inner_types.map.with_index { |_, i| "#{inner_keys[i]}: v#{i}" }.join(", ") %>)
  end

  def native : ::NamedTuple(<%= inner_types.map.with_index { |type, i| "#{inner_keys[i]}: #{type.native_type_expr}" }.join(", ") %>)
    address = data_pointer
    <% inner_types.each_with_index do |type, i| %>
      v<%= i %> = <%= type.crystal_class_name %>.fetch_single(address).native
      address += <%= type.refsize %>
    <% end %>
    ::NamedTuple.new(<%= inner_types.map.with_index { |_, i| "#{inner_keys[i]}: v#{i}" }.join(", ") %>)
  end

  def self.memsize
    <%= memsize %>
  end

  def self.refsize
    <%= refsize %>
  end
end
