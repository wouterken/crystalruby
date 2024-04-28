# frozen_string_literal: true

require_relative "../test_helper"

CrystalRuby::Types::Type.trace_live_objects!

class TestNamedTuple < Minitest::Test
  class NamedTupPrimitive < CRType { NamedTuple(age: Int32, count: Int32) }
  end

  class NamedTup < CRType { NamedTuple(complex: Hash(Int32, Int32), age: Int32, name: String) }
  end

  class NamedTupNested < CRType do
                           NamedTuple(nested: NamedTuple(complex: Hash(Int32, Int32), age: Int32, name: String))
                         end
  end

  def test_named_tuple_construction_primitive
    nt = NamedTupPrimitive.new(age: 25, count: 3)
    nt = nil
  end

  def test_named_tuple_construction
    nt = NamedTup.new(complex: { 1 => 3 }, age: 25, name: "John")
    assert_equal nt.complex, { 1 => 3 }
    assert_equal nt.age, 25
    assert_equal nt.name, "John"
    nt = nil

    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  def test_named_tuple_updates
    nt = NamedTup.new(complex: { 1 => 3 }, age: 25, name: "John")
    nt2_shallow = nt.dup
    nt2_deep = nt.deep_dup

    nt.name = "Steve"
    nt.complex[1] = 88
    assert_equal nt2_deep.complex, { 1 => 3 }
    assert_equal nt2_shallow.complex, { 1 => 88 }
    assert_equal nt2_shallow.name, "Steve"
    refute_equal nt2_deep.name, "Steve"

    nt = nt2_shallow = nt2_deep = nil
    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  def test_named_tuple_nested_construction
    nt = NamedTupNested.new(nested: { complex: { 1 => 3 }, age: 25, name: "John" })

    assert_equal nt.nested[:complex], { 1 => 3 }
    assert_equal nt.nested[:age], 25
    assert_equal nt.nested[:name], "John"
    nt = nil

    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  crystalize
  def accepts_nested_tuple(input: NamedTupNested, returns: Bool)
    true
  end

  crystalize
  def returns_nested_tuple(returns: NamedTupNested)
    NamedTupNested.new(
      { nested: { complex: { 1 => 3 }, age: 25, name: "John" } }
    )
  end

  def test_accepts_nested_tuple
    assert_equal true, accepts_nested_tuple(
      NamedTupNested[nested: { complex: { 1 => 3 }, age: 25, name: "John" }]
    )
  end

  def test_returns_nested_tuple
    val = NamedTupNested[nested: { complex: { 1 => 3 }, age: 25, name: "John" }]
    assert_equal returns_nested_tuple, val
  end

  crystalize
  def returns_simple_tuple(returns: NamedTupPrimitive)
    NamedTupPrimitive.new(
      { age: 18, count: 43 }
    )
  end

  def test_returns_simple_tuple
    assert_equal returns_simple_tuple, NamedTupPrimitive[age: 18, count: 43]
  end
end
