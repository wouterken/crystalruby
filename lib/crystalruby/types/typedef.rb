# frozen_string_literal: true

require_relative "type_serializer"

module CrystalRuby
  module Types
    class Typedef; end

    def self.Typedef(type)
      return type if type.is_a?(Class) && type < Typedef

      Class.new(Typedef) do
        define_singleton_method(:union_types) do
          [self]
        end

        define_singleton_method(:anonymous?) do
          name.nil?
        end

        define_singleton_method(:valid?) do
          type.valid?
        end

        define_singleton_method(:type) do
          type
        end

        define_singleton_method(:type_expr) do
          anonymous? ? type.type_expr : name
        end

        define_singleton_method(:type_defn) do
          type.type_expr
        end

        define_singleton_method(:|) do |other|
          raise "Cannot union non-crystal type #{other}" unless other.is_a?(Type) || other.is_a?(Typedef)

          UnionType.new(*union_types, *other.union_types)
        end

        define_singleton_method(:inspect) do
          "<#{name || "AnonymousType"} #{type.inspect}>"
        end

        define_singleton_method(:serialize_as) do |format|
          TypeSerializer.for(format).new(self)
        end

        define_singleton_method(:interpret!) do |raw|
          type.interpret!(raw)
        end
      end
    end
  end
end
