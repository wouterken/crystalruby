# frozen_string_literal: true

require_relative "../test_helper"

class TestHash < Minitest::Test
  class PrimitiveHash < CRType { Hash(Int32, Int32) }
  end

  class ArrayHash < CRType { Hash(Int32, Array(Int32)) }
  end

  class ArrayHash2 < CRType { Hash(Array(Int32), Int32) }
  end

  class HashArray < CRType { Array(Hash(Int32, Int32)) }
  end

  class HashHash < CRType { Hash(Int32, Hash(Int32, Int32)) }
  end

  class HashHash2 < CRType { Hash(Hash(Int32, Int32), Int32) }
  end

  ComplexValue = CRType do
    Hash(
      Int32,
      Array(
        NamedTuple(
          name: String,
          age: Int32
        )
      )
    )
  end

  ComplexKey = CRType do
    Hash(
      Array(
        NamedTuple(
          name: String,
          age: Int32
        )
      ),
      Int32
    )
  end

  ComplexHash = CRType do
    Hash(
      NamedTuple(
        name: String,
        age: Int32
      ),
      Array(
        NamedTuple(
          name: String,
          age: Int32
        )
      )
    )
  end

  def test_primitive_hash_construction
    hsh = PrimitiveHash[1 => 2, 3 => 4]
    hsh = nil
  end

  def test_array_hash_construction
    hsh = ArrayHash[1 => [2, 3], 4 => [5, 6]]
    hsh = nil
  end

  def test_array_hash_construction2
    hsh = ArrayHash2[[1, 2] => 3, [4, 5] => 6]
    hsh = nil
  end

  def test_hash_array_construction
    hsh = HashArray[{ 1 => 2, 3 => 4 }, { 5 => 6, 7 => 8 }]
    hsh = nil
  end

  def test_hash_hash_construction
    hsh = HashHash[1 => { 2 => 3, 4 => 5 }, 6 => { 7 => 8, 9 => 10 }]
    hsh = nil
  end

  def test_hash_hash_construction2
    hsh = HashHash2[{ 1 => 2, 3 => 4 } => 5, { 6 => 7, 8 => 9 } => 10]
    hash = nil
  end

  def test_complex_key_construction
    hsh = ComplexKey[
      [{ name: "John", age: 25 }] => 43
    ]
    hsh = nil
  end

  def test_complex_value_construction
    hsh = ComplexValue[
      43 => [{ name: "John", age: 25 }]
    ]
    hsh = nil
  end

  def test_complex_hash_construction
    hsh = ComplexHash[
      { name: "John", age: 25 } => [
        { name: "Steve", age: 30 },
        { name: "Jane", age: 28 }
      ]
    ]
    hsh = nil
  end

  def test_complex_hash_manipulation
    hsh = ComplexHash[
      { name: "John", age: 25 } => [
        { name: "Steve", age: 30 },
        { name: "Jane", age: 28 }
      ]
    ]
    3.times.map do
      Thread.new do
        GC.start
        sleep 0.02
      end
    end.map(&:join)
    hsh2_shallow = hsh.dup
    hsh.keys.first[:name] = "Steve"
    assert_equal hsh2_shallow.keys.first[:name], "Steve"
    hsh = nil
  end


  crystallize
  def crystal_mutate_complex_hash!(hash: ComplexHash)
    hash[{ name: "John", age: 25 }][0] = { name: "Alice", age: 18 }
    hash[{ name: "John", age: 25 }][1] = { name: "Bob", age: 30 }
  end

  def test_complex_hash_manipulation_crystal
    hash = ComplexHash[
      { name: "John", age: 25 } => [
        { name: "Steve", age: 30 },
        { name: "Jane", age: 28 }
      ]
    ]
    crystal_mutate_complex_hash!(hash)
    assert_equal hash[{ name: "John", age: 25 }][0][:name], "Alice"
    assert_equal hash[{ name: "John", age: 25 }][1][:name], "Bob"
  end

  class SimpleHash < CRType { Hash(String, Int32) }
  end

  crystallize
  def crystal_mutate_simple_hash!(hash: SimpleHash)
    hash["first"] = 10
    hash["second"] = 20
  end

  def test_simple_hash_manipulation_crystal
    hash = SimpleHash[
      "a" => 1,
      "b" => 2,
      "c" => 3
    ]
    hash["a"] = 9
    hash["b"] = 11
    crystal_mutate_simple_hash!(hash)
    assert_equal hash.native, { "first" => 10, "second" => 20, "a" => 9, "b" => 11, "c" => 3 }
  end

  class UnionHash < CRType { Hash(String, Nil | Int32) }
  end

  crystallize
  def crystal_mutate_union_hash!(hash: UnionHash)
    hash["first"] = 10
    hash["second"] = nil
  end

  def test_union_hash_manipulation_crystal
    hash = UnionHash[
      "a" => 1,
      "b" => nil,
      "c" => 3
    ]
    hash["a"] = nil
    hash["b"] = 11

    crystal_mutate_union_hash!(hash)
    assert_equal hash.native, { "first" => 10, "second" => nil, "a" => nil, "b" => 11, "c" => 3 }
  end
end
