# This is the template used for all CrystalRuby functions
# Calls to this method *from ruby* are first transformed through the lib function.
# Crystal code can simply call this method directly, enabling generated crystal code
# to call other generated crystal code without overhead.

%{module_or_class} %{module_name} %{superclass}
  def %{fn_scope}%{fn_name}(%{fn_args}) : %{fn_ret_type}
    %{convert_lib_args}
    cb = %{module_name}.%{callback_name}
    unless cb.nil?
      callback_done_channel = Channel(Nil).new
      return_value = nil
      if Fiber.current == Thread.current.main_fiber
        return_value = cb.call(%{lib_fn_arg_names})
        return %{convert_return_type}
      else
        CrystalRuby.queue_callback(->{
          return_value = cb.call(%{lib_fn_arg_names})
          callback_done_channel.send(nil)
        })
      end
      callback_done_channel.receive
      return %{convert_return_type}
    end
    raise "No callback registered for %{fn_name}"

  end

  class_property %{callback_name} : Proc(%{lib_fn_types} %{lib_fn_ret_type})?
end

fun register_%{callback_name}(callback : Proc(%{lib_fn_types} %{lib_fn_ret_type})) : Void
  %{module_name}.%{callback_name} = callback
end
