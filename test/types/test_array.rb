# frozen_string_literal: true

require_relative "../test_helper"

class TestArray < Minitest::Test
  IntArrayType = CRType { Array(Int32) }
  NestedArrayType = CRType { Array(Array(Int32)) }

  def test_simply_array_constructor
    ia = IntArrayType[1, 2, 3, 4, 5]
    ia = nil
    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  def test_nested_array_constructor
    ia = NestedArrayType[[1, 2, 3, 4, 5]]
    ia = nil
    assert_equal CrystalRuby::Types::Type.live_objects, 0
  end

  crystalize
  def double_list_of_ints!(a: IntArrayType)
    a.map! { |x| x * 2 }
  end

  def test_forward_mutable
    ia = IntArrayType.new([1, 2, 3, 4, 5])
    double_list_of_ints!(ia)
    assert ia == [2, 4, 6, 8, 10]
  end

  crystalize
  def double_nested_list_of_ints!(a: NestedArrayType)
    a.map! { |b| b.map! { |c| c * 2 } }
  end

  def test_forward_mutable
    ia = NestedArrayType.new([[1, 2, 3, 4, 5]])
    double_nested_list_of_ints!(ia)
    assert ia == [[2, 4, 6, 8, 10]]
  end

  crystalize
  def mutate_and_access_named_types!(a: NestedArrayType, value: Int32, returns: Int32)
    a[0][0] = value
    a[0][1] = 43
    raise "Expected #{value} but got #{a[0][0]}" if a[0][0].value != value

    a[0][1].value
  end

  def test_forward_mutable
    ia = NestedArrayType.new([[1, 2, 3, 4, 5]])
    assert mutate_and_access_named_types!(ia, 42) == 43
    assert ia == [[42, 43, 3, 4, 5]]
  end

  crystalize
  def mutate_and_access_anonymous!(a: Array(Array(Bool)), value: Bool, returns: Bool)
    a[0][0] = value
    a[0][1] = true
    a[0][2] = false
    raise "Expected #{value} but got #{a[0][0]}" if a[0][0] != value

    a[0][1]
  end

  def test_mutate_and_access_anonymous
    assert mutate_and_access_anonymous!([[false, false, false]], true) == true
  end

  crystalize
  def mutate_and_access_nil_array!(a: Array(Array(Nil)), value: Nil, returns: Nil)
    a[0][0] = value
    a[0][1] = nil
    a[0][2] = nil
    raise "Expected #{value} but got #{a[0][0]}" if a[0][0] != value

    a[0][1]
  end

  def test_mutate_and_access_nil_array
    assert mutate_and_access_nil_array!([[nil, nil, nil]], nil).nil?
  end

  ColorSymbol = CRType { Symbol(:green, :blue, :orange) }
  crystalize
  def mutate_and_access_symbol_array!(a: Array(Array(ColorSymbol)), value: ColorSymbol, returns: ColorSymbol)
    a[0][0] = :orange
    a[0][1] = :green
    a[0][2] = value
    raise "Expected #{value} but got #{a[0][2]}" if a[0][2] != value

    a[0][1]
  end

  def test_mutate_and_access_symbol_array
    assert mutate_and_access_symbol_array!([%i[orange blue green]], :orange) == :green
  end

  crystalize
  def mutate_and_access_time_array!(a: Array(Array(Time)), value: Time, returns: Time)
    a[0][0] = Time.local
    a[0][1] = Time.local - 100.seconds
    a[0][2] = value
    raise "Expected #{value} but got #{a[0][2]}" if a[0][2] != value

    a[0][1]
  end

  def mutate_and_access_time_array
    assert mutate_and_access_time_array!([[Time.at(0), Time.at(1_000_000), Time.now]],
                                         Time.at(43)) == Time.at(1_000_000)
  end

  ComplexArray = CRType do
    Array(
      NamedTuple(
        name: String,
        age: Int32
      )
    )
  end

  crystalize
  def crystal_mutate_complex_array!(array: ComplexArray)
    array[0] = { name: "Alice", age: 30 }
    array << { name: "Bob", age: 25 }
  end

  def test_complex_array_manipulation_crystal
    array = ComplexArray[
      { name: "Steve", age: 30 },
      { name: "Jane", age: 28 }
    ]
    array[0] = { name: "Abbie", age: 39 }
    array << { name: "Albert", age: 30 }

    crystal_mutate_complex_array!(array)
    assert_equal array.native, [
      { name: "Alice",  age: 30 },
      { name: "Jane",   age: 28 },
      { name: "Albert", age: 30 },
      { name: "Bob",    age: 25 }
    ]
  end

  class SimpleArray < CRType do
    Array(Int32)
  end
  end

  crystalize
  def crystal_mutate_simple_array!(array: SimpleArray)
    array[0] = 4
    array << 8
  end

  def test_simple_array_manipulation_crystal
    array = SimpleArray[1, 2, 3]
    array[0] = 9
    array << 11

    crystal_mutate_simple_array!(array)
    assert_equal array.native, [4, 2, 3, 11, 8]
  end

  class UnionArray < CRType do
    Array(Nil | Int32)
  end
  end

  crystalize
  def crystal_mutate_union_array!(array: UnionArray)
    array[0] = 4
    array[2] = nil
    array << 8
    array << nil
  end

  def test_union_array_manipulation_crystal
    array = UnionArray[1, nil, 2, nil, 3]
    array[0] = nil
    array[1] = 8
    array << 3
    array << nil

    crystal_mutate_union_array!(array)
    assert_equal array.native, [4, 8, nil, nil, 3, 3, nil, 8, nil]
  end
end
