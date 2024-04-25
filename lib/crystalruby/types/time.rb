# frozen_string_literal: true

module CrystalRuby::Types
  require "date"
  Time = Type.new(:Time, accept_if: [::Time, ::String]) do |v|
    DateTime.parse(v)
  end
end
