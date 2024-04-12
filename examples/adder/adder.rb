require "crystalruby"

module Adder
  crystalize [a: :int, b: :int] => :int
  def add(a, b)
    a + b
  end
end

puts Adder.add(1, 2)
