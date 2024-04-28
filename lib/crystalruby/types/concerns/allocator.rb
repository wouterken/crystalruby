module CrystalRuby
  module Types
    module Allocator

      NULL_BYTES = [0,0,0,0].freeze

      def self.included(base)
        base.class_eval do
          def self.synchronize(&block)
            Type::ARC_MUTEX.synchronize(&block)
          end

          def self.schedule!(&block)
            Type::ARC_MUTEX.schedule!(&block)
          end

          extend FFI::Library
          ffi_lib "c"
          attach_function :_malloc, :malloc, [:size_t], :pointer
          attach_function :_free, :free, [:pointer], :void
          define_singleton_method(:ptr, &FFI::Pointer.method(:new))
          define_method(:ptr, &FFI::Pointer.method(:new))

          extend Forwardable


          def malloc(size)
            self.class.malloc(size)
          end

          def self.malloc(size)
            result = _malloc(size)
            result.put_array_of_int8(0, NULL_BYTES)
            traced_live_objects[result.address] = result if trace_live_objects?
            result
          end

          def self.free(ptr)
            traced_live_objects.delete(ptr.address) if trace_live_objects?
            _free(ptr)
          end

          def self.traced_live_objects
            @traced_live_objects ||= {}
          end

          def self.trace_live_objects!
            @trace_live_objects = true
          end

          def self.trace_live_objects?
            !!@trace_live_objects
          end

          def self.live_objects
            traced_live_objects.count
          end
        end
      end
    end
  end
end
