
module CrystalRuby
  module Types
    # Store references to root types so that we can reference these in places where
    # we load the CrystalRuby equivalents into the global namespace
    module Root
      Symbol = ::Symbol
      String = ::String
      Array = ::Array
      Hash = ::Hash
      Time = ::Time
    end

    def self.const_missing(const_name)
      return @fallback.const_get(const_name) if @fallback&.const_defined?(const_name)
      super
    end

    def self.method_missing(method_name, *args)
      return @fallback.send(method_name, *args) if @fallback&.method_defined?(method_name)
      super
    end

    def self.with_binding_fallback(fallback)
      @fallback, previous_fallback = fallback, @fallback
      @fallback = @fallback.class unless @fallback.kind_of?(Module)
      yield binding
    ensure
      @fallback = previous_fallback
    end
  end
end
require_relative "types/concerns/allocator"
require_relative "types/type"
require_relative "types/primitive"
require_relative "types/fixed_width"
require_relative "types/variable_width"
