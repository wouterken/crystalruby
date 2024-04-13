alias ErrorCallback = (Pointer(UInt8), Pointer(UInt8), UInt32 -> Void)

ARGV1 = "crystalruby"
CALLBACK_MUX = Mutex.new

module CrystalRuby
  # Initializing Crystal Ruby invokes init on the Crystal garbage collector.
  # We need to be sure to only do this once.
  @@initialized = false

  # Our Ruby <-> Crystal Reactor uses Fibers, with callbacks to allow
  # multiple concurrent Crystal operations to be queued
  @@callbacks = [] of Proc(Nil)

  # We only continue to yield to the Crystal scheduler from Ruby
  # while there are outstanding tasks.
  @@task_counter : Atomic(Int32) = Atomic.new(0)

  # We can override the error callback to catch errors in Crystal,
  # and explicitly expose them to Ruby.
  @@error_callback : ErrorCallback = ->(t : UInt8* , s : UInt8*, tid : UInt32){ puts "Error: #{t}:#{s}" }

  # This is the entry point for instantiating CrystalRuby
  # We:
  # 1. Initialize the Crystal garbage collector
  # 2. Set the error callback
  # 3. Call the Crystal main function
  def self.init(error_callback : ErrorCallback)
    return if @@initialized
    @@initialized = true
    GC.init
    argv_ptr = ARGV1.to_unsafe
    Crystal.main(0, pointerof(argv_ptr))
    @@error_callback = error_callback
  end

  # Explicit error handling (triggers exception within Ruby on the same thread)
  def self.report_error(error_type : String, str : String, thread_id : UInt32, )
    @@error_callback.call(error_type.to_unsafe, str.to_unsafe, thread_id)
  end

  def self.error_callback : ErrorCallback
    @@error_callback
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
    @@task_counter.get()
  end

  # Queue a callback for an async task
  def self.queue_callback(callback : Proc(Nil))
    CALLBACK_MUX.synchronize do
      @@callbacks << callback
    end
  end

  # Get number of queued callbacks
  def self.count_callbacks : Int32
    @@callbacks.size
  end

  # Flush all callbacks
  def self.flush_callbacks : Int32
    CALLBACK_MUX.synchronize do
      count = @@callbacks.size
      @@callbacks.each do |callback|
        result = callback.call()
      end
      @@callbacks.clear
    end
    get_task_counter
  end
end

# Initialize CrystalRuby
fun init(cb : ErrorCallback): Void
  CrystalRuby.init(cb)
end

fun stop(): Void
  GC.disable
end

# Yield to the Crystal scheduler from Ruby
# If there's callbacks to process, we flush them
# Otherwise, we yield to the Crystal scheduler and let Ruby know
# how many outstanding tasks still remain (it will stop yielding to Crystal
# once this figure reaches 0).
fun yield() : Int32
  if CrystalRuby.count_callbacks == 0

    Fiber.yield

    # TODO: We should apply backpressure here to prevent busy waiting if the number of outstanding tasks is not decreasing.
    # Use a simple exponential backoff strategy, to increase the time between each yield up to a maximum of 1 second.

    CrystalRuby.get_task_counter
  else
    CrystalRuby.flush_callbacks()
  end
end


# This is where we define all our Crystal modules and types
# derived from their Ruby counterparts.
%{type_modules}

# Require all generated crystal files
require "json"
%{requires}
