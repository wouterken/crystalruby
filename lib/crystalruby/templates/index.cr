FAKE_ARG = "crystal"

alias ErrorCallback = (Pointer(UInt8), Pointer(UInt8) -> Void)

module CrystalRuby
  # Initializing Crystal Ruby invokes init on the Crystal garbage collector.
  # We need to be sure to only do this once.
  @@initialized = false

  # We won't natively handle Crystal Exceptions in Ruby
  # Instead, we'll catch them in Crystal, and explicitly expose them to Ruby via
  # the error_callback.
  @@error_callback

  # This is the entry point for instantiating CrystalRuby
  # We:
  # 1. Initialize the Crystal garbage collector
  # 2. Set the error callback
  # 3. Call the Crystal main function
  def self.init(error_callback : ErrorCallback)
    return if @@initialized
    GC.init
    @@initialized    = true
    @@error_callback = error_callback
    ptr = FAKE_ARG.to_unsafe
    LibCrystalMain.__crystal_main(1, pointerof(ptr))
  end

  # Explicit error handling (triggers exception within Ruby on the same thread)
  def self.report_error(error_type : String, str : String)
    if handler = @@error_callback
      handler.call(error_type.to_unsafe, str.to_unsafe)
    end
  end
end

fun init(cb : ErrorCallback): Void
  CrystalRuby.init(cb)
end

# This is where we define all our Crystal modules and types
# derived from their Ruby counterparts.
%{type_modules}

# Require all generated crystal files
%{requires}
