# frozen_string_literal: true

module CrystalRuby::Types
  NamedTuple = Type.new(
    :NamedTuple,
    error: "NamedTuple type must contain one or more symbol -> type pairs. E.g. NamedTuple(hello: Int32, world: String)"
  )

  def self.NamedTuple(types_hash)
    types_hash.keys.each do |key|
      raise "NamedTuple keys must be symbols" unless key.is_a?(::Symbol) || key.respond_to?(:to_sym)
    end
    types_hash.values.each do |value_type|
      Type.validate!(value_type)
    end
    keys = types_hash.keys.map(&:to_sym)
    values = types_hash.values
    Type.new("NamedTuple", inner_types: values, inner_keys: keys, accept_if: [::Hash]) do |h|
      h.transform_keys! { |k| k.to_sym }
      raise "Invalid keys for named tuple" unless h.keys.length == keys.length
      raise "Invalid keys for named tuple" unless h.keys.all? { |k| keys.include?(k) }

      h.each do |key, value|
        h[key] = values[keys.index(key)].interpret!(value)
      end
    end
  end
end
