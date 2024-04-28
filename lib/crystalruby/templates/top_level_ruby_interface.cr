# This is the template used for all CrystalRuby functions
# Calls to this method *from ruby* are first transformed through the lib function.
# Crystal code can simply call this method directly, enabling generated crystal code
# to call other generated crystal code without overhead.

module TopLevelCallbacks
  class_property %{fn_name}_callback : Proc(%{lib_fn_types} %{lib_fn_ret_type})?
end

def %{fn_scope}%{fn_name}(%{fn_args}) : %{fn_ret_type}
  %{convert_lib_args}
  cb = TopLevelCallbacks.%{fn_name}_callback
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

fun register_%{fn_name}_callback(callback : Proc(%{lib_fn_types} %{lib_fn_ret_type})) : Void
  TopLevelCallbacks.%{fn_name}_callback = callback
end
