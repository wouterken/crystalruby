module CrystalRuby::Types
  %i[Uint8 Uint16 Uint32 Uint64 Int8 Int16 Int32 Int64 Float32 Float64].each do |type_name|
    const_set type_name, Type.new(type_name, accept_if: [::Numeric])
  end
end
