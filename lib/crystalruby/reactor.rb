module CrystalRuby
  require 'json'
  # The Reactor represents a singleton Thread responsible for running all Ruby/crystal interop code.
  # Crystal's Fiber scheduler and GC assume all code is run on a single thread.
  # This class is responsible for multiplexing Ruby and Crystal code onto a single thread.
  # Functions annotated with async: true, are executed using callbacks to allow these to be interleaved
  # without blocking multiple Ruby threads.
  module Reactor
    module_function

    class SingleThreadViolation < StandardError; end
    class StopReactor < StandardError; end

    @single_thread_mode = false

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

    ERROR_CALLBACK = FFI::Function.new(:void, %i[string string string int]) do |error_type, message, backtrace, tid|
      error_type = error_type.to_sym
      is_exception_type = Object.const_defined?(error_type) && Object.const_get(error_type).ancestors.include?(Exception)
      error_type = is_exception_type ? Object.const_get(error_type) : RuntimeError
      error = error_type.new(message)
      error.set_backtrace(JSON.parse(backtrace))
      raise error  unless THREAD_MAP.key?(tid)

      THREAD_MAP[tid][:error] = error
      THREAD_MAP[tid][:result] = nil
      THREAD_MAP[tid][:cond].signal
    end

    def thread_conditions
      THREAD_MAP[Thread.current]
    end

    def await_result!
      mux, cond, result, err = thread_conditions.values_at(:mux, :cond, :result, :error)
      cond.wait(mux) unless (result || err)
      result, err, thread_conditions[:result], thread_conditions[:error] = thread_conditions.values_at(:result, :error)
      if err
        combined_backtrace = err.backtrace[0..(err.backtrace.index{|m| m.include?('call_blocking_function')} || 2) - 3] + caller[5..-1]
        err.set_backtrace(combined_backtrace)
        raise err
      end

      result
    end

    def halt_loop!
      raise StopReactor
    end

    def stop!
      if @main_loop
        schedule_work!(self, :halt_loop!, :void, blocking: true, async: false)
        @main_loop.join
        @main_loop = nil
        CrystalRuby.log_info "Reactor loop stopped"
      end
    end

    def start!
      @main_loop ||= Thread.new do
        @main_thread_id = Thread.current.object_id
        CrystalRuby.log_debug("Starting reactor")
        CrystalRuby.log_debug("CrystalRuby initialized")
        while true
          handler, *args = REACTOR_QUEUE.pop
          send(handler, *args)
        end
      rescue StopReactor => e
      rescue StandardError => e
        CrystalRuby.log_error "Error: #{e}"
        CrystalRuby.log_error e.backtrace
      end
    end

    def thread_id
      Thread.current.object_id
    end

    def yield!(lib: nil, time: 0.0)
      schedule_work!(lib, :yield, :int, async: false, blocking: false, lib: lib) if running? && lib
      nil
    end

    def invoke_async!(receiver, op_name, *args, thread_id, callback, lib)
      receiver.send(op_name, *args, thread_id, callback)
      yield!(lib: lib, time: 0)
    end

    def invoke_blocking!(receiver, op_name, *args, tvars)
      tvars[:error] = nil
      begin
        tvars[:result] = receiver.send(op_name, *args)
      rescue StopReactor => e
        tvars[:cond].signal
        raise
      rescue StandardError => e
        tvars[:error] = e
      end
      tvars[:cond].signal
    end

    def invoke_await!(receiver, op_name, *args, lib)
      outstanding_jobs = receiver.send(op_name, *args)
      yield!(lib: lib, time: 0) unless outstanding_jobs == 0
    end

    def schedule_work!(receiver, op_name, *args, return_type, blocking: true, async: true, lib: nil)
      if @single_thread_mode || (Thread.current.object_id == @main_thread_id && op_name != :yield)
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
          when async then [:invoke_async!, receiver, op_name, *args, tvars[:thread_id], CALLBACKS_MAP[return_type], lib]
          when blocking then [:invoke_blocking!, receiver, op_name, *args, tvars]
          else [:invoke_await!, receiver, op_name, *args, lib]
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
