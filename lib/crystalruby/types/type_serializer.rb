module CrystalRuby::Types
  class TypeSerializer
    include FFI::DataConverter
    def self.for(format)
      case format
      when :json then JSON
      else raise "Unknown type format: #{format}"
      end
    end

    def error_value
      0
    end

    def initialize(typedef)
      @typedef = typedef
    end

    def type_expr
      @typedef.type_expr
    end

    def type_defn
      @typedef.type_defn
    end

    def anonymous?
      @typedef.anonymous?
    end

    def name
      @typedef.name
    end
  end
end

require_relative "type_serializer/json"
