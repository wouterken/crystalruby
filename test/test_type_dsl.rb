# frozen_string_literal: true

require_relative "test_helper"

class TestTypeDSL < Minitest::Test
  def test_simple_numeric_types
    %i[UInt8 UInt16 UInt32 UInt64 Int8 Int16 Int32 Int64 Float32 Float64].first(2).each do |typename|
      tp = CrystalRuby::Types.const_get(typename)

      numeric_object = tp.new(100)

      # We've allocated a single pointer
      assert numeric_object == 100
      numeric_object.value = 5

      # We've still only allocated a single pointer, but swapped out the value
      assert numeric_object == 5

      # Acts like pointed object if methods aren't defined on type
      assert numeric_object + 40 == 45

      assert_raises(RuntimeError) { numeric_object.value = :not_a_number }
    end
  end

  def test_simple_string
    string_tp = CRType { String }

    string_value = string_tp.new("Hello World")

    # We've allocated a pointer to our string (which in itself is a pointer to a char)

    assert string_value == "Hello World"

    # We create a new char * and update the our string value address to point to it
    string_value.value = "Goodbye World"

    assert string_value == "Goodbye World"
  end

  def test_simple_symbol
    symbol_tp = CRType { Symbol(:"Hello World", :"Goodbye World") }

    symbol = symbol_tp.new(:"Hello World")

    # We've allocated a pointer to our string (which in itself is a pointer to a char)

    assert symbol == :"Hello World"

    # We create a new char * and update the our string value address to point to it
    symbol.value = :"Goodbye World"

    assert symbol == :"Goodbye World"
  end

  def test_simple_time
    time_tp = CRType { Time }

    time = time_tp.new(Time.at(0))

    # Times are just stored as doubles

    time.value += 86_400 # 1 day
    assert_equal time, Time.at(86_400)
  end

  def test_primitive_union
    int_or_bool = CRType { Int32 | Bool }

    iob = int_or_bool.new(38)
    assert iob == 38

    iob.value = true
    assert iob == true

    assert_raises(CrystalRuby::InvalidCastError) { iob.value = "not a number or bool" }
  end

  def test_primitive_array
    optional_int_or_bool_array = CRType { Array(Int32 | Bool | Nil) }

    ia = optional_int_or_bool_array[1, 2, 3, 4, 5, false, true, false, nil]
    assert ia[0] == 1

    ia[1] = 2
    assert ia[1] == 2

    ia[3] = nil

    assert ia[3].nil?

    ia.value = [5, nil, false, 4, 3, 2, 1]

    assert ia == [5, nil, false, 4, 3, 2, 1]

    assert_raises(CrystalRuby::InvalidCastError) { ia.value = [1, 2, 3, 4, "not a number or bool or nil"] }
  end

  def test_primitive_hash
    numeric_to_opt_bool_hash = CRType { Hash(Float64 | Int32, Bool | Nil) }

    hash = numeric_to_opt_bool_hash[5 => true, 7 => false, 8.8 => nil]
    assert hash[5] == true
    assert hash[7] == false
    assert hash[8.8].nil?
    hash[5] = nil
    hash[7] = true
    hash[8.8] = false

    assert hash[5].nil?
    assert hash[7] == true
    assert hash[8.8] == false
    assert hash == { 5.0 => nil, 7.0 => true, 8.8 => false }

    hash.value = { 9 => true, 8 => false, 0.4 => nil }
    assert hash == { 9.0 => true, 8.0 => false, 0.4 => nil }

    shallow_copy = hash.dup
    deep_copy = hash.deep_dup

    shallow_copy[9] = nil
    deep_copy[9] = false

    assert hash[9].nil?
    assert deep_copy[9] == false

    assert_raises(CrystalRuby::InvalidCastError) { hash[:not_found] = 33 }
  end
end
