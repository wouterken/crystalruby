module CrystalRuby
  ARGV1 = "crystalruby"

  alias ErrorCallback = (Pointer(::UInt8), Pointer(::UInt8), Pointer(::UInt8), ::UInt32 -> Void)

  class_property libname : String = "crystalruby"
  class_property callbacks : Channel(Proc(Nil)) = Channel(Proc(Nil)).new
  class_property rc_mux : Pointer(Void) = Pointer(Void).null
  class_property task_counter : Atomic(Int32) = Atomic(Int32).new(0)

  # Initializing Crystal Ruby invokes init on the Crystal garbage collector.
  # We need to be sure to only do this once.
  class_property initialized : Bool = false

  # We can override the error callback to catch errors in Crystal,
  # and explicitly expose them to Ruby.
  @@error_callback : ErrorCallback?

  # This is the entry point for instantiating CrystalRuby
  # We:
  # 1. Initialize the Crystal garbage collector
  # 2. Set the error callback
  # 3. Call the Crystal main function
  def self.init(libname : Pointer(::UInt8), @@error_callback : ErrorCallback, @@rc_mux : Pointer(Void))
    return if self.initialized
    self.initialized = true
    argv_ptr = ARGV1.to_unsafe
    {%% if compare_versions(Crystal::VERSION, "1.16.0") >= 0  %%}
      Crystal.init_runtime
    {%% end %%}
    Crystal.main_user_code(0, pointerof(argv_ptr))
    self.libname = String.new(libname)
    GC.init
  end

  # Explicit error handling (triggers exception within Ruby on the same thread)
  def self.report_error(error_type : String, message : String, backtrace : String, thread_id : UInt32)
    if error_reporter = @@error_callback
      error_reporter.call(error_type.to_unsafe, message.to_unsafe, backtrace.to_unsafe, thread_id)
    end
  end

  # New async task started
  def self.increment_task_counter
    @@task_counter.add(1)
  end

  # Async task finished
  def self.decrement_task_counter
    @@task_counter.sub(1)
  end

  # Get number of outstanding tasks
  def self.get_task_counter : Int32
    @@task_counter.get
  end

  # Queue a callback for an async task
  def self.queue_callback(callback : Proc(Nil))
    self.callbacks.send(callback)
  end

  def self.synchronize(&)
    LibC.pthread_mutex_lock(self.rc_mux)
    yield
    LibC.pthread_mutex_unlock(self.rc_mux)
  end
end

# Initialize CrystalRuby
fun init(libname : Pointer(::UInt8), cb : CrystalRuby::ErrorCallback, rc_mux : Pointer(Void)) : Void
  CrystalRuby.init(libname, cb, rc_mux)
end

fun stop : Void
  LibGC.deinit
end

@[Link("gc")]
lib LibGC
  $stackbottom = GC_stackbottom : Void*
  fun deinit = GC_deinit
  fun set_finalize_on_demand = GC_set_finalize_on_demand(Int32)
  fun invoke_finalizers = GC_invoke_finalizers : Int
end

lib LibC
  fun calloc = calloc(Int32, Int32) : Void*
end

module GC
  def self.current_thread_stack_bottom
    {Pointer(Void).null, LibGC.stackbottom}
  end

  def self.set_stackbottom(stack_bottom : Void*)
    LibGC.stackbottom = stack_bottom
  end

  def self.collect
    LibGC.collect
    LibGC.invoke_finalizers
  end
end

# Trigger GC
fun gc : Void
  GC.collect
end

# Yield to the Crystal scheduler from Ruby
# If there's callbacks to process, we flush them
# Otherwise, we yield to the Crystal scheduler and let Ruby know
# how many outstanding tasks still remain (it will stop yielding to Crystal
# once this figure reaches 0).
fun yield : Int32
  Fiber.yield
  loop do
    select
    when callback = CrystalRuby.callbacks.receive
      callback.call
    else
      break
    end
  end
  CrystalRuby.get_task_counter
end

class Array(T)
  def initialize(size : Int32, @buffer : Pointer(T))
    @size = size.to_i32
    @capacity = @size
  end
end

require "json"
%{requires}
