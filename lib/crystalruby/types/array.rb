# frozen_string_literal: true

module CrystalRuby::Types
  Array = Type.new(
    :Array,
    error: "Array type must have a type parameter. E.g. Array(Float64)"
  )

  def self.Array(type)
    Type.validate!(type)
    Type.new("Array", inner_types: [type], accept_if: [::Array]) do |a|
      a.map! { |v| type.interpret!(v) }
    end
  end
end
