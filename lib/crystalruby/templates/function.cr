# This is the template used for all CrystalRuby functions
# Calls to this method *from ruby* are first transformed through the lib function.
# Crystal code can simply call this method directly, enabling generated crystal code
# to call other generated crystal code without overhead.

module %{module_name}
  def self.%{fn_name}(%{fn_args}) : %{fn_ret_type}
    %{fn_body}
  end
end

# This function is the entry point for the CrystalRuby code, exposed through FFI.
# We apply some basic error handling here, and convert the arguments and return values
# to ensure that we are using Crystal native types.
fun %{lib_fn_name}(%{lib_fn_args}): %{lib_fn_ret_type}
  begin
    %{convert_lib_args}
    begin
      return_value = %{module_name}.%{fn_name}(%{arg_names})
      return %{convert_return_type}
    rescue ex
      CrystalRuby.report_error("RuntimeError", ex.message.to_s, 0)
    end
  rescue ex
    CrystalRuby.report_error("ArgumentError", ex.message.to_s, 0)
  end
  return %{error_value}
end


# This function is the async entry point for the CrystalRuby code, exposed through FFI.
# We apply some basic error handling here, and convert the arguments and return values
# to ensure that we are using Crystal native types.
fun %{lib_fn_name}_async(%{lib_fn_args} thread_id: UInt32,  callback : %{callback_type}): Void
  begin
    %{convert_lib_args}
    CrystalRuby.increment_task_counter
    spawn do
      begin
        return_value = %{module_name}.%{fn_name}(%{arg_names})
        converted = %{convert_return_type}
        CrystalRuby.queue_callback(->{
          %{callback_call}
          CrystalRuby.decrement_task_counter
        })
      rescue ex
        exception = ex.message.to_s
        CrystalRuby.queue_callback(->{
          CrystalRuby.error_callback.call("RuntimeError".to_unsafe, exception.to_unsafe, thread_id)
          CrystalRuby.decrement_task_counter
        })
      end
    end
  rescue ex

    exception = ex.message.to_s
    CrystalRuby.queue_callback(->{
      CrystalRuby.error_callback.call("RuntimeError".to_unsafe, ex.message.to_s.to_unsafe, thread_id)
      CrystalRuby.decrement_task_counter
    })
  end
end
