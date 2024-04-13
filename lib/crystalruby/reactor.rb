module CrystalRuby
  module Reactor
    module_function

    class ReactorStoppedException < StandardError; end
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

    def thread_id
      Thread.current.object_id
    end

    def yield!(time: 0)
      Thread.new do
        sleep time
        schedule_work!(Reactor, :yield, nil, async: false, blocking: false)
      end
    end

    def current_thread_id=(val)
      @current_thread_id = val
    end

    def current_thread_id
      @current_thread_id
    end

    def schedule_work!(receiver, op_name, *args, return_type, blocking: true, async: true)
      raise ReactorStoppedException, "Reactor has been terminated, no new work can be scheduled" if @stopped

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
              yield!(time: 0)
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
              yield!(time: 0.01) unless outstanding_jobs.zero?
            }
          end
        )
        return await_result! if blocking
      end
    end

    def init_single_thread_mode!
      @single_thread_mode = true
      @main_thread_id = Thread.current.object_id
      init_crystal_ruby!
    end

    def init_crystal_ruby!
      attach_lib!
      init(ERROR_CALLBACK)
    end

    def attach_lib!
      CrystalRuby.log_debug("Attaching lib")
      extend FFI::Library
      ffi_lib CrystalRuby.config.crystal_lib_dir / CrystalRuby.config.crystal_lib_name
      attach_function :init, [:pointer], :void
      attach_function :stop, [], :void
      attach_function :yield, %i[], :int
    end

    def stop!
      CrystalRuby.log_debug("Stopping reactor")
      @stopped = true
      sleep 1
      @main_loop&.kill
      @main_loop = nil
      CrystalRuby.log_debug("Reactor stopped")
    end

    def running?
      @main_loop&.alive?
    end

    def start!
      @main_loop ||= begin
        attach_lib!
        Thread.new do
          CrystalRuby.log_debug("Starting reactor")
          init(ERROR_CALLBACK)
          CrystalRuby.log_debug("CrystalRuby initialized")
          loop do
            REACTOR_QUEUE.pop[]
            break if @stopped
          end
          stop
          CrystalRuby.log_debug("Stopping reactor")
        rescue StandardError => e
          puts "Error: #{e}"
          puts e.backtrace
        end
      end
    end

    at_exit do
      @stopped = true
    end
  end
end
