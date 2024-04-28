# frozen_string_literal: true

require_relative "test_helper"

class TestTypeTransforms < Minitest::Test
  include Adder
  module ::Adder
    crystalize :bool
    def complex_argument_types(a: Int64 | Float64 | Nil, b: String | Array(Bool))
      true
    end

    crystalize -> { Int32 | String | Hash(String, Array(NamedTuple(hello: Int32)) | Time) }
    def complex_return_type
      {
        "hello" => [
          {
            hello: 1
          }
        ],
        "world" => Time.utc
      }
    end

    crystalize -> { Int32 | String | Hash(String, Array(NamedTuple(hello: Array(Int32))) | Time) }
    def complex_return_type
      {
        "hello" => [
          {
            hello: [1]
          }
        ],
        "world" => Time.utc
      }
    end

    crystalize -> { Array(NamedTuple(hello: Array(Int32))) }
    def array_named_tuple_int_array
      [{ hello: [1, 2, 3] }]
    end

    crystalize -> { Array(Int32) }
    def prim_array
      [9, 8, 7]
    end

    crystalize -> { Array(Array(Int32)) }
    def nested_prim_array
      [[1, 8, 7], [5]]
    end

    crystalize -> { Array(Array(Array(Array(Int32 | Nil)))) }
    def triple_nested_union_array
      [[[[9, 8, 7, nil]], [[1, 2, 3, nil]]]]
    end

    crystalize -> { Hash(Hash(Hash(Hash(Hash(Int32, Int32), Int32), Int32), Int32), String) }
    def five_nested_key_nested_hash
      {
        { { { { 1 => 2 } => 3 } => 4 } => 5 } => "hello"
      }
    end

    crystalize -> { Hash(Int32, Hash(Int32, Hash(Int32, Hash(Int32, Hash(Int32, String))))) }
    def five_nested_value_nested_hash
      { 1 => { 2 => { 3 => { 4 => { 5 => "hello" } } } } }
    end

    crystalize -> { Tuple(Tuple(Tuple(Tuple(Int32, String, Array(Int32))))) }, raw: true
    def four_nested_tuple
      %({ { { {  1, "hello", [1,2,3] } } } })
    end

    crystalize lambda {
      NamedTuple(value: NamedTuple(value: NamedTuple(value: NamedTuple(age: Int32, name: String, flags: Array(Int32)))))
    }
    def four_named_tuple
      { value: { value: { value: { age: 1, name: "hello", flags: [1, 2, 3] } } } }
    end

    IntArrOrBoolArr = CRType { Array(Bool) | Array(Int32) }

    crystalize
    def method_with_named_types(a: IntArrOrBoolArr, returns: IntArrOrBoolArr)
      a
    end
  end

  def test_triple_nested_union_array
    assert_equal triple_nested_union_array, [[[[9, 8, 7, nil]], [[1, 2, 3, nil]]]]
  end

  def test_five_nested_key_nested_hash
    assert_equal five_nested_key_nested_hash, { { { { { 1 => 2 } => 3 } => 4 } => 5 } => "hello" }
  end

  def test_five_nested_value_nested_hash
    assert_equal five_nested_value_nested_hash, { 1 => { 2 => { 3 => { 4 => { 5 => "hello" } } } } }
  end

  def test_four_nested_tuple
    assert_equal four_nested_tuple, [[[[1, "hello", [1, 2, 3]]]]]
  end

  def test_four_named_tuple
    assert_equal four_named_tuple, { value: { value: { value: { age: 1, name: "hello", flags: [1, 2, 3] } } } }
  end

  def test_complex_argument_types
    assert complex_argument_types(1, "hello")
    assert complex_argument_types(1.0, [true])
    assert_raises(CrystalRuby::InvalidCastError) { complex_argument_types(1.0, [true, "not a bool"]) }
    assert_raises(CrystalRuby::InvalidCastError) { complex_argument_types(true, "string") }
  end

  def test_complex_return_type
    assert complex_return_type["hello"] == [
      {
        hello: [1]
      }
    ]
    assert complex_return_type["world"].is_a?(Time)
  end

  def test_named_types
    assert method_with_named_types([1, 1, 1]) == [1, 1, 1]
    input = IntArrOrBoolArr[[true, false, true]]
    assert method_with_named_types(input) == [true, false, true]
    assert_raises(CrystalRuby::InvalidCastError) { method_with_named_types([true, 5, "bad"]) }
  end
end
