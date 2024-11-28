require "crystalruby"

module Adder
  crystalize :int
  def add(a: :int, b: :int)
    a + b
  end
end

puts Adder.add(1, 2)
