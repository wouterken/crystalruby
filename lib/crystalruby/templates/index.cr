FAKE_ARG = "crystal"
alias Callback = (Pointer(UInt8), Pointer(UInt8) -> Void)

module CrystalRuby
  @@initialized = false
  def self.init
    if @@initialized
      return
    end
    @@initialized = true
    GC.init
    ptr = FAKE_ARG.to_unsafe
    LibCrystalMain.__crystal_main(1, pointerof(ptr))
  end

  def self.attach_rb_error_handler(cb : Callback)
    @@rb_error_handler = cb
  end

  def self.report_error(error_type : String, str : String)
    handler = @@rb_error_handler
    if handler
      handler.call(error_type.to_unsafe, str.to_unsafe)
    end
  end
end


fun init(): Void
  CrystalRuby.init
end

fun attach_rb_error_handler(cb : Callback) : Void
  CrystalRuby.attach_rb_error_handler(cb)
end

%{type_modules}
%{requires}
