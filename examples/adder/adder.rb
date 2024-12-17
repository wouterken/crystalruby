require "crystalruby"

module Adder
  crystallize :int
  def add(a: :int, b: :int)
    a + b
  end
end

puts Adder.add(1, 2)
