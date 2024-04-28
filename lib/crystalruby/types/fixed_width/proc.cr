class <%= base_crystal_class_name %> < CrystalRuby::Types::FixedWidth

  def initialize(inner_proc : Proc(<%= inner_types.map(&:native_type_expr).join(",") %>))
    @memory = malloc(20) # 4 bytes RC + 2x 8 Byte Pointer
    self.value = inner_proc
    increment_ref_count!
  end

  def ==(other : <%= native_type_expr %>)
    native == other
  end

  def value : Proc(<%= inner_types.map(&:crystal_type).join(",") %>)
    func_ptr = Pointer(Void).new((@memory+4).as(Pointer(::UInt64)).value)
    Proc(<%= inner_types.map(&:crystal_type).join(",") %>).new(func_ptr, Pointer(Void).null)
  end

  def native : Proc(<%= inner_types.map(&:crystal_type).join(",") %>)
    value
  end

  def value=(inner_proc : Proc(<%= inner_types.map(&:native_type_expr).join(",") %>))
    # We can't maintain a direct reference to our inner_proc within our callback
    # as this turns it into a closure, which we cannot pass over FFI.
    # Instead, we box the inner_proc and pass a pointer to the box to the callback.
    # and then unbox it within the callback.

    boxed_data = Box.box(inner_proc)

    callback_ptr = Proc(Pointer(::UInt8), <%= inner_types.map(&:crystal_type).join(",") %>).new do |<%= inner_types.size.times.map{|i| "_v#{i}" }.join(",") %>|

      inner_prc = Box(typeof(inner_proc)).unbox(_v0.as(Pointer(Void)))
      <% inner_types.each.with_index do |inner_type, i| %>
        <% next if i == inner_types.size - 1 %>
        v<%= i.succ %> = <%= inner_type.crystal_class_name %>.new(_v<%= i.succ %>)<%= inner_type.anonymous? ? ".value" : "" %>
      <% end %>

      return_value = inner_prc.call(<%= inner_types.size.-(1).times.map{|i| "v#{i.succ}" }.join(",") %>)
      <%= inner_types[-1].crystal_class_name %>.new(return_value).return_value
    end.pointer

    (@memory+4).as(Pointer(::UInt64)).value = callback_ptr.address
    (@memory+12).as(Pointer(::UInt64)).value = boxed_data.address
  end
end
