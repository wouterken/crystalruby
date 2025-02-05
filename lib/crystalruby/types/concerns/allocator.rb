module CrystalRuby
  module Types
    # Module for memory allocation and tracking functionality
    module Allocator
      # Called when module is included in a class
      # @param base [Class] The class including this module

      def self.gc_hint!(size)
        @bytes_seen_since_gc = (@bytes_seen_since_gc || 0) + size
      end

      def self.gc_bytes_seen
        @bytes_seen_since_gc ||= 0
      end

      def self.gc_hint_reset!
        @bytes_seen_since_gc = 0
      end

      def self.included(base)
        base.class_eval do
          # Synchronizes a block using mutex
          # @yield Block to be synchronized
          def self.synchronize(&block)
            Type::ARC_MUTEX.synchronize(&block)
          end

          # Schedules a block for execution
          # @yield Block to be scheduled
          def self.schedule!(&block)
            Type::ARC_MUTEX.schedule!(&block)
          end

          extend FFI::Library
          ffi_lib "c"
          attach_function :_calloc, :calloc, %i[size_t size_t], :pointer
          attach_function :_free, :free, [:pointer], :void
          define_singleton_method(:ptr, &FFI::Pointer.method(:new))
          define_method(:ptr, &FFI::Pointer.method(:new))

          extend Forwardable

          # Instance method to allocate memory
          # @param size [Integer] Size in bytes to allocate
          # @return [FFI::Pointer] Pointer to allocated memory
          def malloc(size)
            self.class.malloc(size)
          end

          # Class method to allocate memory
          # @param size [Integer] Size in bytes to allocate
          # @return [FFI::Pointer] Pointer to allocated memory
          def self.malloc(size)
            result = _calloc(size, 1)
            traced_live_objects[result.address] = result if trace_live_objects?
            result
          end

          # Frees allocated memory
          # @param ptr [FFI::Pointer] Pointer to memory to free
          def self.free(ptr)
            traced_live_objects.delete(ptr.address) if trace_live_objects?
            _free(ptr)
          end

          # Returns hash of traced live objects
          # @return [Hash] Map of addresses to pointers
          def self.traced_live_objects
            @traced_live_objects ||= {}
          end

          # Enables tracing of live objects
          def self.trace_live_objects!
            @trace_live_objects = true
          end

          # Checks if live object tracing is enabled
          # @return [Boolean] True if tracing is enabled
          def self.trace_live_objects?
            !!@trace_live_objects
          end

          # Returns count of live objects being tracked
          # @return [Integer] Number of live objects
          def self.live_objects
            traced_live_objects.count
          end
        end
      end
    end
  end
end
