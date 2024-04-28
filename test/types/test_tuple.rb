# frozen_string_literal: true

require_relative "../test_helper"

CrystalRuby::Types::Type.trace_live_objects!

class TestTuple < Minitest::Test
  class TupPrimitive < CRType { Tuple(Int32, Int32) }
  end

  class Tup < CRType { Tuple(Hash(Int32, Int32), Int32, String) }
  end

  class TupNested < CRType do
                      Tuple(NamedTuple(complex: Hash(Int32, Int32), age: Int32, name: String))
                    end
  end

  def test_tuple_construction_primitive
    nt = TupPrimitive[25, 3]
    nt = nil
  end

  def test_tuple_construction
    nt = Tup[{ 1 => 3 }, 25, "John"]
    assert_equal nt[0], { 1 => 3 }
    assert_equal nt[1], 25
    assert_equal nt[2], "John"
    nt = nil

    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  def test_tuple_updates
    nt = Tup[{ 1 => 3 }, 25, "John"]
    nt2_shallow = nt.dup
    nt2_deep = nt.deep_dup

    nt[2] = "Steve"
    nt[0][1] = 88
    assert_equal nt2_shallow[0], { 1 => 88 }

    assert_equal nt2_shallow[2], "Steve"
    refute_equal nt2_deep[2], "Steve"
    nt2_shallow = nil
    nt2_deep = nil
    nt = nil
    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  def test_tuple_nested_construction
    nt = TupNested[{ complex: { 1 => 3 }, age: 25, name: "John" }]

    assert_equal nt[0][:complex], { 1 => 3 }
    assert_equal nt[0][:age], 25
    assert_equal nt[0][:name], "John"
    nt = nil

    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  crystalize
  def accepts_nested_tuple(input: TupNested, returns: Bool)
    true
  end

  crystalize raw: true
  def returns_nested_tuple(returns: TupNested)
    %{
      inner = { complex: { 1 => 3 }, age: 25, name: "John" }
      TupNested.new({ inner })
    }
  end

  def test_accepts_nested_tuple
    assert_equal true, accepts_nested_tuple(
      TupNested[{ complex: { 1 => 3 }, age: 25, name: "John" }]
    )
  end

  def test_returns_nested_tuple
    val = TupNested[{ complex: { 1 => 3 }, age: 25, name: "John" }]
    assert_equal returns_nested_tuple, val
  end

  crystalize raw: true
  def returns_simple_tuple(returns: TupPrimitive)
    %{
      TupPrimitive.new({18, 43})
    }
  end

  def test_returns_simple_tuple
    assert_equal returns_simple_tuple, TupPrimitive[18, 43]
  end

  crystalize
  def mutates_tuple_primitive!(input: TupPrimitive, returns: TupPrimitive)
    input[0] = 42
    input[1] = 79
    input
  end

  crystalize
  def doubles_tuple_values!(input: TupPrimitive)
    input[0] = input[0].not_nil! * 2
    input[1] = input[1].not_nil! * 2
  end

  def test_mutates_tuple_primitive
    tp = TupPrimitive[18, 43]
    mutates_tuple_primitive!(tp)
    assert_equal tp, TupPrimitive[42, 79]
    tp[0] = 99
    tp[1] = 158
    doubles_tuple_values!(tp)
    assert_equal tp, TupPrimitive[198, 316]
  end

  crystalize
  def mutates_tuple_complex!(input: TupNested, returns: TupNested)
    input[0].not_nil!.complex = { 1 => 42 }
    input[0].not_nil!.age = 79
    input
  end

  def test_mutates_tuple_complex
    tp = TupNested[{ complex: { 1 => 3 }, age: 25, name: "John" }]
    mutates_tuple_complex!(tp)
    assert_equal tp, TupNested[{ complex: { 1 => 42 }, age: 79, name: "John" }]
  end

  crystalize
  def mutates_tuple_nested!(input: TupNested, returns: TupNested)
    puts input[0].not_nil!.complex.class
    input[0].not_nil!.complex[1] = 42
    input[0].not_nil!.age = 79
    input
  end

  def test_mutates_tuple_nested
    tp = TupNested[{ complex: { 1 => 3 }, age: 25, name: "John" }]
    mutates_tuple_nested!(tp)
    assert_equal tp, TupNested[{ complex: { 1 => 42 }, age: 79, name: "John" }]
  end
end
