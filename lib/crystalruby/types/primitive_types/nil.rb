module CrystalRuby::Types
  Nil = Primitive.build(:Nil, convert_if: [::NilClass], memsize: 0) do
    def initialize(val = nil)
      super
      @value = 0
    end

    def nil?
      true
    end

    def value(native: false)
      nil
    end
  end
end
