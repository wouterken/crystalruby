module CrystalRuby::Types
  Symbol = Type.new(:Symbol, accept_if: [::String, ::Symbol])
end
