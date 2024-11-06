class <%= base_crystal_class_name %> < CrystalRuby::Types::VariableWidth

  include Enumerable(<%= inner_type.native_type_expr %>)

  def initialize(array : Array(<%= inner_type.native_type_expr %>))
    @memory = malloc(data_offset + 8)
    self.value = array
    increment_ref_count!
  end

  def each
    size.times do |i|
      yield self[i].native
    end
  end

  def ==(other : Array(<%= inner_type.native_type_expr %>))
    native == other
  end

  def data_pointer
    Pointer(::UInt8).new((@memory + data_offset).as(Pointer(::UInt64)).value)
  end

  def value=(array : Array(<%= inner_type.native_type_expr %>))
    if self.ref_count > 0
      self.class.decr_inner_ref_counts!(memory)
    end
    self.class.copy_to!(array, self.memory)
  end

  def <<(value : <%= inner_type.native_type_expr %>)
    self.value = self.native + [value]
  end

  def []=(index : Int, value : <%= inner_type.native_type_expr %>)
    index += size if index < 0
    <%= inner_type.crystal_class_name %>.write_single(data_pointer + index * <%= inner_type.refsize %>, value)
  end

  def [](index : Int)
    index += size if index < 0
    <%= inner_type.crystal_class_name %>.fetch_single(data_pointer + index * <%= inner_type.refsize %>)
  end

  def self.copy_to!(array : Array(<%= inner_type.native_type_expr %>), memory : Pointer(::UInt8))
    data_pointer = malloc(array.size * <%= inner_type.refsize %>)
    array.size.times do |i|
      <%= inner_type.crystal_class_name %>.write_single(data_pointer + i * <%= inner_type.refsize %>, array[i])
    end
    (memory+size_offset).as(Pointer(::UInt32)).value = array.size.to_u32
    (memory+data_offset).as(Pointer(::UInt64)).value = data_pointer.address
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def value
    <%= inner_type.crystal_class_name %>.fetch_multi!(data_pointer, size)
  end

  def native : ::Array(<%= inner_type.native_type_expr %>)
    <%= inner_type.crystal_class_name %>.fetch_multi_native!(data_pointer, size)
  end

  def size
    (@memory + self.class.size_offset).as(Pointer(::UInt32))[0]
  end

  def self.memsize
    <%= memsize %>
  end
end
