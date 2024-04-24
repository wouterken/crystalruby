# frozen_string_literal: true

require_relative "test_helper"

class TestCrystalRubyTypes < Minitest::Test
  include Adder
  module ::Adder
    crystalize [a: json{ Int64 | Float64 | Nil }, b: json{ String | Array(Bool)  } ] => :bool
    def complex_argument_types
      return true
    end

    crystalize [] => json{ Int32 | String | Hash(String, Array(NamedTuple(hello: Int32)) | Time)}
    def complex_return_type
      return {
        "hello" => [
          {
            hello: 1,
          },
        ],
        "world" => Time.utc
      }
    end

    IntArrOrBoolArr = json{ Array(Bool) | Array(Int32) }

    crystalize [a: IntArrOrBoolArr] => IntArrOrBoolArr
    def method_with_named_types(a)
      return a
    end
  end

  def test_complex_argument_types
    assert complex_argument_types( 1, "hello")
    assert complex_argument_types( 1.0, [true])
    refute (complex_argument_types( 1.0, [true, "not a bool"]) rescue false)
    refute (complex_argument_types( true, "string") rescue false)
  end

  def test_complex_return_type
    assert complex_return_type["hello"] ==  [
      {
        hello: 1,
      }
    ]

    assert complex_return_type["world"].is_a?(DateTime)
  end

  def test_named_types
    assert method_with_named_types([1,1,1]) == [1,1,1]
    assert method_with_named_types([true, false, true]) == [true, false, true]
    refute ( method_with_named_types([true, 5, "bad"]) rescue false )
  end
end
