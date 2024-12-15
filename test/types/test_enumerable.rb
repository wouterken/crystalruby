# frozen_string_literal: true

require_relative "../test_helper"

class TestEnumerable < Minitest::Test
  TestComplexArrayType = CRType { Array(Hash(Int32, Int32)) }

  crystallize
  def cr_non_destructive_map(array: TestComplexArrayType, returns: Array(Int32))
    array.map { |x| x.values.max }
  end

  crystallize
  def cr_desctructive_map(array: TestComplexArrayType)
    array.map! { |x| x.transform_values { |v| v * 2 } }
  end

  def test_arr_map_cr
    test_array = TestComplexArrayType[{ 1 => 3 }, { 2 => 4 }, { 3 => 5 }]
    # Non destructive map works as expected
    assert_equal cr_non_destructive_map(test_array), [3, 4, 5]

    # Destructive map must return a compatible type (Type system enforces this)
    cr_desctructive_map(test_array)
    assert_equal test_array, [{ 1 => 6 }, { 2 => 8 }, { 3 => 10 }]
  end

  crystallize
  def find_hash_with_key(array: TestComplexArrayType, key: Int32, returns: Hash(Int32, Int32))
    array.find { |x| x.keys.includes?(key) }.not_nil!
  end

  def test_arr_find_cr
    test_array = TestComplexArrayType[{ 1 => 3 }, { 2 => 4 }, { 3 => 5 }]
    found = find_hash_with_key(test_array, 3)
    assert_equal found, { 3 => 5 }
  end

  crystallize
  def group_by_max_value(array: TestComplexArrayType, returns: Hash(Int32, Array(Hash(Int32, Int32))))
    array.group_by { |x| x.values.max }.not_nil!
  end

  def test_arr_group_by_cr
    test_array = TestComplexArrayType[{ 1 => 3, 8 => 2 }, { 2 => 4, 1 => 5 }, { 3 => 5 }, { 5 => 2 }]
    found = group_by_max_value(test_array)
    assert_equal found, { 3 => [{ 1 => 3, 8 => 2 }], 5 => [{ 2 => 4, 1 => 5 }, { 3 => 5 }], 2 => [{ 5 => 2 }] }
  end

  crystallize
  def reduce_sum_values(array: TestComplexArrayType, returns: Int32)
    array.reduce(0) { |acc, x| acc + x.values.sum }
  end

  def test_arr_reduce_cr
    test_array = TestComplexArrayType[{ 1 => 3, 8 => 2 }, { 2 => 4, 1 => 5 }, { 3 => 5 }, { 5 => 2 }]
    assert_equal reduce_sum_values(test_array), 21
  end

  def test_arr_map_rb
    test_array = TestComplexArrayType[{ 1 => 3 }, { 2 => 4 }, { 3 => 5 }]
    # Non destructive map works as expected
    assert_equal test_array.map { |x| x.values.max }, [3, 4, 5]

    # Destructive map must return a compatible type
    test_array.map! { |x| x.transform_values { |v| v * 2 } }

    # Otherwise, it raises an error
    assert_raises(CrystalRuby::InvalidCastError) do
      test_array.map! do |x|
        x.transform_values do |_v|
          "Incompatible type"
        end
      end
    end
  end

  def test_arr_find_rb
    test_array = TestComplexArrayType[{ 1 => 3, 8 => 2 }, { 2 => 4, 1 => 5 }, { 3 => 5 }, { 5 => 2 }]
    assert_equal test_array.find { |x| x.keys.include?(3) }, { 3 => 5 }
  end

  def test_arr_group_by_rb
    test_array = TestComplexArrayType[{ 1 => 3, 8 => 2 }, { 2 => 4, 1 => 5 }, { 3 => 5 }, { 5 => 2 }]
    assert_equal test_array.group_by { |x|
                   x.values.max
                 }, { 3 => [{ 1 => 3, 8 => 2 }], 5 => [{ 2 => 4, 1 => 5 }, { 3 => 5 }], 2 => [{ 5 => 2 }] }
  end

  def test_arr_reduce_rb
    test_array = TestComplexArrayType[{ 1 => 3, 8 => 2 }, { 2 => 4, 1 => 5 }, { 3 => 5 }, { 5 => 2 }]
    assert_equal test_array.reduce(0) { |acc, x| acc + x.values.sum }, 21
  end

  TestComplexHashType = CRType { Hash(Int32, Array(Int32)) }

  def test_hash_map_cr; end

  def test_hash_map_rb; end

  def test_hash_find_cr; end

  def test_hash_find_rb; end

  def test_hash_group_by_cr; end

  def test_hash_group_by_rb; end

  def test_hash_reduce_cr; end

  def test_hash_reduce_rb; end
end
