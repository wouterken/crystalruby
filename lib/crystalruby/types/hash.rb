module CrystalRuby::Types
  Hash = Type.new(
    :Hash,
    error: "Hash type must have 2 type parameters. E.g. Hash(Float64, String)",
  )

  def self.Hash(key_type, value_type)
    Type.validate!(key_type)
    Type.validate!(value_type)
    Type.new("Hash", inner_types: [key_type, value_type], accept_if: [::Hash]) do |h|
      h.transform_keys!{|k| key_type.interpret!(k) }
      h.transform_values!{|v| value_type.interpret!(v) }
    end
  end
end
