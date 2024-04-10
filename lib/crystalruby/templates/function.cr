module %{module_name}
  def self.%{fn_name}(%{fn_args}) : %{fn_ret_type}
    %{fn_body}
  end
end

fun %{lib_fn_name}(%{lib_fn_args}): %{lib_fn_ret_type}
  begin
    %{convert_lib_args}
    begin
      return_value = %{module_name}.%{fn_name}(%{arg_names})
      return %{convert_return_type}
    rescue ex
      CrystalRuby.report_error("RuntimeError", ex.message.to_s)
    end
  rescue ex
    CrystalRuby.report_error("ArgumentError", ex.message.to_s)
  end
  return %{error_value}
end
