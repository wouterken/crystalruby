module CrystalRuby::Types
  Bool = Primitive.build(:Bool, convert_if: [::TrueClass, ::FalseClass], ffi_type: :uint8, memsize: 1) do
    def value(native: false)
      super == 1
    end

    def value=(val)
      !!val && val != 0 ? super(1) : super(0)
    end
  end
end
