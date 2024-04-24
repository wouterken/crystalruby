module CrystalRuby
  # The Reactor represents a singleton Thread
  # responsible for running all Ruby/crystal interop code.
  # Crystal's Fiber scheduler and GC assumes all code is run on a single thread.
  # This class is responsible for multiplexing Ruby and Crystal code on a single thread,
  # to allow safe invocation of Crystal code from across any number of Ruby threads.
  # Functions annotated with async: true, are executed using callbacks to allow these to be multi-plexed in a non-blocking manner.

  module Reactor
    module_function

    class SingleThreadViolation < StandardError; end

    REACTOR_QUEUE = Queue.new

    # We maintain a map of threads, each with a mutex, condition variable, and result
    THREAD_MAP = Hash.new do |h, tid_or_thread, tid = tid_or_thread|
      if tid_or_thread.is_a?(Thread)
        ObjectSpace.define_finalizer(tid_or_thread) do
          THREAD_MAP.delete(tid_or_thread)
          THREAD_MAP.delete(tid_or_thread.object_id)
        end
        tid = tid_or_thread.object_id
      end

      h[tid] = {
        mux: Mutex.new,
        cond: ConditionVariable.new,
        result: nil,
        thread_id: tid
      }
      h[tid_or_thread] = h[tid] if tid_or_thread.is_a?(Thread)
    end

    # We memoize callbacks, once per return type
    CALLBACKS_MAP = Hash.new do |h, rt|
      h[rt] = FFI::Function.new(:void, [:int, *(rt == :void ? [] : [rt])]) do |tid, ret|
        THREAD_MAP[tid][:error] = nil
        THREAD_MAP[tid][:result] = ret
        THREAD_MAP[tid][:cond].signal
      end
    end

    ERROR_CALLBACK = FFI::Function.new(:void, %i[string string int]) do |error_type, message, tid|
      error_type = error_type.to_sym
      is_exception_type = Object.const_defined?(error_type) && Object.const_get(error_type).ancestors.include?(Exception)
      error_type = is_exception_type ? Object.const_get(error_type) : RuntimeError
      tid = tid.zero? ? Reactor.current_thread_id : tid
      raise error_type.new(message) unless THREAD_MAP.key?(tid)

      THREAD_MAP[tid][:error] = error_type.new(message)
      THREAD_MAP[tid][:result] = nil
      THREAD_MAP[tid][:cond].signal
    end

    def thread_conditions
      THREAD_MAP[Thread.current]
    end

    def await_result!
      mux, cond = thread_conditions.values_at(:mux, :cond)
      cond.wait(mux)
      raise THREAD_MAP[thread_id][:error] if THREAD_MAP[thread_id][:error]

      THREAD_MAP[thread_id][:result]
    end

    def start!
      @main_loop ||= Thread.new do
        CrystalRuby.log_debug("Starting reactor")
        CrystalRuby.log_debug("CrystalRuby initialized")
        loop do
          REACTOR_QUEUE.pop[]
        end
      rescue StandardError => e
        CrystalRuby.log_error "Error: #{e}"
        CrystalRuby.log_error e.backtrace
      end
    end

    def thread_id
      Thread.current.object_id
    end

    def yield!(lib: nil, time: 0.0)
      schedule_work!(lib, :yield, nil, async: false, blocking: false, lib: lib) if running? && lib
      nil
    end

    def current_thread_id=(val)
      @current_thread_id = val
    end

    def current_thread_id
      @current_thread_id
    end

    def schedule_work!(receiver, op_name, *args, return_type, blocking: true, async: true, lib: nil)
      if @single_thread_mode
        unless Thread.current.object_id == @main_thread_id
          raise SingleThreadViolation,
                "Single thread mode is enabled, cannot run in multi-threaded mode. " \
                "Reactor was started from: #{@main_thread_id}, then called from #{Thread.current.object_id}"
        end

        return receiver.send(op_name, *args)
      end

      tvars = thread_conditions
      tvars[:mux].synchronize do
        REACTOR_QUEUE.push(
          case true
          when async
            lambda {
              receiver.send(
                op_name, *args, tvars[:thread_id],
                CALLBACKS_MAP[return_type]
              )
              yield!(lib: lib, time: 0)
            }
          when blocking
            lambda {
              tvars[:error] = nil
              Reactor.current_thread_id = tvars[:thread_id]
              begin
                result = receiver.send(op_name, *args)
              rescue StandardError => e
                tvars[:error] = e
              end
              tvars[:result] = result unless tvars[:error]
              tvars[:cond].signal
            }
          else
            lambda {
              outstanding_jobs = receiver.send(op_name, *args)
              yield!(lib: lib, time: 0) unless outstanding_jobs == 0
            }
          end
        )
        return await_result! if blocking
      end
    end

    def running?
      @main_loop&.alive?
    end

    def init_single_thread_mode!
      @single_thread_mode ||= begin
        @main_thread_id = Thread.current.object_id
        true
      end
    end
  end
end
