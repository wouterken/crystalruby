class <%= base_crystal_class_name %> < CrystalRuby::Types::VariableWidth

  def initialize(hash : Hash(<%= key_type.native_type_expr %>, <%= value_type.native_type_expr %>))
    @memory = malloc(data_offset + 8)
    self.value = hash
    increment_ref_count!
  end

  def value=(hash : Hash(<%= key_type.native_type_expr %>, <%= value_type.native_type_expr %>))
    if self.ref_count > 0
      self.class.decr_inner_ref_counts!(memory)
    end
    self.class.copy_to!(hash, self.memory)
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def self.copy_to!(hash : Hash(<%= key_type.native_type_expr %>, <%= value_type.native_type_expr %>), memory : Pointer(::UInt8))
    data_pointer = malloc(hash.size * (keysize +  valsize)).as(Pointer(::UInt8))

    hash.keys.each_with_index do |key, i|
      <%= key_type.crystal_class_name %>.write_single(data_pointer + i * keysize, key)
    end

    hash.values.each_with_index do |value, i|
      <%= value_type.crystal_class_name %>.write_single(data_pointer + hash.size * keysize + i * valsize, value)
    end

    (memory+size_offset).as(Pointer(::UInt32)).value = hash.size.to_u32
    (memory+data_offset).as(Pointer(::UInt64)).value = data_pointer.address
  end

  def value
    ::Hash.zip(keys, values)
  end

  def native : ::Hash(<%= key_type.native_type_expr %>, <%= value_type.native_type_expr %>)
    ::Hash.zip(keys_native, values_native)
  end

  include Enumerable(::Tuple(<%= key_type.native_type_expr %>, <%= value_type.native_type_expr %>))

  def each
    size.times do |i|
      yield({keys_native[i], values_native[i]})
    end
  end

  def size
    (memory+size_offset).as(Pointer(::UInt32)).value.to_i
  end

  def self.keysize
    <%= key_type.refsize %>
  end

  def keysize
    <%= key_type.refsize %>
  end

  def self.valsize
    <%= value_type.refsize %>
  end

  def valsize
    <%= value_type.refsize %>
  end

  def []=(key : <%= key_type.native_type_expr %>, value : <%= value_type.native_type_expr %>)
    index = index_of(key)
    if index
      <%= value_type.crystal_class_name %>.write_single(data_pointer + size * keysize + index * valsize, value)
    else
      self.value = self.native.merge({key => value})
    end
  end

  def key_ptr : Pointer(<%= !key_type.numeric? ? "UInt64" : key_type.native_type_expr %>)
    data_pointer.as(Pointer(<%= !key_type.numeric? ? "UInt8" : key_type.native_type_expr %>))
  end

  def value_ptr : Pointer(<%= !value_type.numeric? ? "UInt64" : value_type.native_type_expr %>)
    (data_pointer + size * keysize).as(Pointer(<%= !value_type.numeric? ? "UInt8" : value_type.native_type_expr %>))
  end

  def []?(key : <%= key_type.native_type_expr %>)
    index = index_of(key)
    if index
      values[index]
    else
      nil
    end
  end

  def [](key : <%= key_type.native_type_expr %>)
    index = index_of(key)
    if index
      values[index]
    else
      raise "Key not found"
    end
  end


  def data_pointer
    Pointer(::UInt8).new((@memory + data_offset).as(::Pointer(UInt64)).value)
  end

  def keys
    keys = [] of <%=  key_type.numeric? ? key_type.native_type_expr : key_type.crystal_class_name %>
    size.times do |i|
      keys << <%= !key_type.numeric? ? "#{key_type.crystal_class_name}.fetch_single(data_pointer + i * keysize)" : "key_ptr[i]" %>
    end
    keys
  end

  def values
    values = [] of <%= value_type.numeric? ? value_type.native_type_expr : value_type.crystal_class_name %>
    size.times do |i|
      values << <%= !value_type.numeric? ? "#{value_type.crystal_class_name}.fetch_single(data_pointer + size * keysize + i * valsize)" : "value_ptr[i]" %>
    end
    values
  end

  def keys_native
    keys = [] of <%= key_type.native_type_expr %>
    size.times do |i|
      keys << <%= !key_type.numeric? ? "#{key_type.crystal_class_name}.fetch_single(data_pointer + i * keysize).native" : "key_ptr[i]" %>.as(<%= key_type.native_type_expr %>)
    end
    keys
  end

  def values_native
    values = [] of <%= value_type.native_type_expr %>
    size.times do |i|
      values << <%= !value_type.numeric? ? "#{value_type.crystal_class_name}.fetch_single(data_pointer + size * keysize + i * valsize).native" : "value_ptr[i]" %>.as(<%= value_type.native_type_expr %>)
    end
    values
  end

  def index_of(key : <%= key_type.native_type_expr %>)
    keys.index(key)
  end
end
