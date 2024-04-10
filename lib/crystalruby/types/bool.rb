module CrystalRuby::Types
  Bool = Type.new(:Bool, accept_if: [::TrueClass, ::FalseClass])
end
