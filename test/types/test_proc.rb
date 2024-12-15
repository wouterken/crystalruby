# frozen_string_literal: true

require_relative "../test_helper"

class TestProcAsync < Minitest::Test
  crystallize async: true
  def crystal_method_takes_bool_int32_closure(yield: Proc(Bool, Int32), returns: Int32)
    yield true
  end

  def test_passes_ruby_proc_to_crystal
    closure_state = []
    return_value = crystal_method_takes_bool_int32_closure do |input|
      assert_equal input, true
      closure_state << 1
      15
    end
    assert_equal closure_state, [1]
    assert_equal return_value, 15
  end

  expose_to_crystal
  def ruby_method_takes_bool_int32_closure(yield: Proc(Bool, Int32), returns: Int32)
    yield true
  end

  crystallize
  def crystal_ruby_method_invoker(returns: Int32)
    crystal_method_takes_bool_int32_closure do |_input|
      15
    end
  end

  def test_passes_crystal_proc_to_ruby
    assert_equal crystal_ruby_method_invoker, 15
  end
end

class TestProcSync < Minitest::Test
  crystallize async: false
  def crystal_method_takes_bool_int32_closure(yield: Proc(Bool, Int32), returns: Int32)
    yield true
  end

  def test_passes_ruby_proc_to_crystal
    closure_state = []
    return_value = crystal_method_takes_bool_int32_closure do |input|
      assert_equal input, true
      closure_state << 1
      15
    end
    assert_equal closure_state, [1]
    assert_equal return_value, 15
  end

  expose_to_crystal
  def ruby_method_takes_bool_int32_closure(yield: Proc(Bool, Int32), returns: Int32)
    yield true
  end

  crystallize
  def crystal_ruby_method_invoker(returns: Int32)
    crystal_method_takes_bool_int32_closure do |_input|
      15
    end
  end

  # def test_passes_crystal_proc_to_ruby
  #   assert_equal crystal_ruby_method_invoker, 15
  # end
end
