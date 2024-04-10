module CrystalRuby::Types
  Tuple = Type.new(
    :Tuple,
    error: "Tuple type must contain one or more types E.g. Tuple(Int32, String)"
  )

  def self.Tuple(*types)
    types.each do |value_type|
      Type.validate!(value_type)
    end
    Type.new("Tuple", inner_types: types, accept_if: [::Array]) do |a|
      a.map!.with_index{|v, i| self.inner_types[i].interpret!(v) }
    end
  end
end
