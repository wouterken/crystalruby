require_relative "types"

module CrystalRuby
  module TypeBuilder
    module_function

    def build_from_source(src, context: )
      source_type = Types.with_binding_fallback(context) do |binding|
        eval(src.is_a?(String) ? src : SourceReader.extract_source_from_proc(src), binding)
      end

      return source_type if source_type.is_a?(Types::Root::Symbol)

      unless source_type.kind_of?(Class) && source_type < Types::Type
        raise "Invalid type #{source_type.inspect}"
      end

      return source_type unless source_type.anonymous?

      source_type.tap do |new_type|
        Types::Type.validate!(new_type)
      end
    end
  end
end
