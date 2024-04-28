# frozen_string_literal: true

require "date"

module CrystalRuby::Types
  Time = Primitive.build(:Time, convert_if: [Root::Time, Root::String, DateTime], ffi_type: :double) do
    def initialize(val = Root::Time.now)
      super
    end

    def value=(val)
      super(
        if val.respond_to?(:to_time)
          val.to_time.to_f
        else
          val.respond_to?(:to_f) ? val.to_f : 0
        end
      )
    end

    def value(native: false)
      ::Time.at(super)
    end
  end
end
