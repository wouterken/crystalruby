
require_relative "test_helper"

class TestInstance < Minitest::Test

  # class Person < CRType{
  #   NamedTuple(
  #     first_name: String,
  #     last_name: String,
  #     age: Int32
  #   )
  # }

  #   crystalize
  #   def first_name_cr=(first_name: String)
  #     self.first_name = first_name
  #   end

  #   crystalize
  #   def first_name_cr(returns: String)
  #     self.first_name
  #   end

  #   expose_to_crystal
  #   def last_name_rb=(last_name: String)
  #     self.last_name = last_name
  #   end

  #   expose_to_crystal
  #   def last_name_rb(returns: String)
  #     self.last_name
  #   end

  #   crystalize
  #   def capitalize_full_name_cr
  #     self.first_name_cr = self.first_name_cr.capitalize
  #     self.last_name_rb = self.last_name_rb.capitalize
  #   end

  #   def lower_case_full_name_rb
  #     self.first_name_cr = self.first_name_cr.capitalize
  #     self.last_name_rb = self.last_name_rb.capitalize
  #   end

  #   crystalize
  #   def yield_cr_to_rb(big: Bool, yields: Proc(Bool, Int32))
  #     return 10 + yield(big)
  #   end

  #   expose_to_crystal
  #   def yield_rb_to_cr(big: Bool, yields: Proc(Bool, Int32))
  #     return 10 + yield(big)
  #   end

  #   crystalize
  #   def invoke_yield_rb_to_cr(big: Bool)
  #     self.yield_rb_to_cr(big) do |big|
  #       if big
  #         10000
  #       else
  #         1
  #       end
  #     end
  #   end

  # end
end
