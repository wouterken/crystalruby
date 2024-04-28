module CrystalRuby
  module LibC
    extend FFI::Library
    ffi_lib "c"
    class PThreadMutexT < FFI::Struct
      layout :__align, :int64, :__size, :char, 40
    end

    attach_function :pthread_mutex_init, [PThreadMutexT.by_ref, :pointer], :int
    attach_function :pthread_mutex_lock, [PThreadMutexT.by_ref], :int
    attach_function :pthread_mutex_unlock, [PThreadMutexT.by_ref], :int
  end

  class ArcMutex
    def phtread_mutex
      @phtread_mutex ||= init_mutex!
    end

    def synchronize
      lock
      yield
      unlock
    end

    def to_ptr
      phtread_mutex.pointer
    end

    def init_mutex!
      mutex = LibC::PThreadMutexT.new
      res = LibC.pthread_mutex_init(mutex, nil)
      raise "Failed to initialize mutex" unless res.zero?

      mutex
    end

    def lock
      res = LibC.pthread_mutex_lock(phtread_mutex)
      raise "Failed to lock mutex" unless res.zero?
    end

    def unlock
      res = LibC.pthread_mutex_unlock(phtread_mutex)
      raise "Failed to unlock mutex" unless res.zero?
    end
  end
end
