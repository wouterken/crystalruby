require_relative "test_helper"

class TestInstance < Minitest::Test
  class Person < CRType do
    NamedTuple(
      first_name: String,
      last_name: String,
      age: Int32
    )
  end

    crystallize
    def first_name_cr=(first_name: String)
      self.first_name = first_name
    end

    crystallize
    def first_name_cr(returns: String)
      first_name.value
    end

    expose_to_crystal
    def last_name_rb=(last_name: String)
      self.last_name = last_name
    end

    expose_to_crystal
    def last_name_rb(returns: :string)
      last_name.value
    end

    crystallize
    def capitalize_full_name_cr
      self.first_name_cr = first_name_cr.capitalize
      self.last_name_rb = last_name_rb.capitalize
    end

    def lower_case_full_name_rb
      self.first_name_cr = first_name_cr.downcase
      self.last_name_rb = last_name_rb.downcase
    end

    crystallize
    def yield_cr_to_rb(big: Bool, yield: Proc(Bool, Int32), returns: Int32)
      10 + yield(big)
    end

    expose_to_crystal
    def yield_rb_to_cr(big: Bool, yield: Proc(Bool, Int32), returns: Int32)
      10 + yield(big)
    end

    crystallize
    def invoke_yield_rb_to_cr(big: Bool, returns: Int32)
      yield_rb_to_cr(big) do |big|
        if big
          10_000
        else
          1
        end
      end
    end
  end

  crystallize
  def construct_person(first_name: String, returns: Person)
    Person.new({ first_name: first_name, last_name: "Doe", age: 30 })
  end

  def test_can_construct_instance
    assert Person.new(first_name: "John", last_name: "Doe", age: 30)
  end

  def test_can_construct_new_instance_in
    person = construct_person("Hi Crystal")
    assert_equal person, Person.new(first_name: "Hi Crystal", last_name: "Doe", age: 30)
  end

  def test_can_update_attribute_in_crystal
    person = Person.new(first_name: "John", last_name: "Doe", age: 30)
    person.first_name_cr = "Steve"
    assert_equal person.first_name_cr, "Steve"
  end

  def test_cross_language_setters
    Person.new(first_name: "john", last_name: "doe", age: 30).tap do |person|
      person.capitalize_full_name_cr
      assert_equal person.first_name, "John"
      assert_equal person.last_name, "Doe"
    end

    Person.new(first_name: "JOHN", last_name: "DOE", age: 30).tap do |person|
      person.lower_case_full_name_rb
      assert_equal person.first_name, "john"
      assert_equal person.last_name, "doe"
    end
  end

  def test_invoke_yield_rb_to_cr
    Person.new(first_name: "john", last_name: "doe", age: 30).tap do |person|
      assert_equal person.invoke_yield_rb_to_cr(true), 10_010
    end

    Person.new(first_name: "john", last_name: "doe", age: 30).tap do |person|
      assert_equal person.invoke_yield_rb_to_cr(false), 11
    end
  end

  def test_yield_cr_to_rb
    Person.new(first_name: "john", last_name: "doe", age: 30).tap do |person|
      assert_equal(person.yield_cr_to_rb(false) { 1234 }, 1244)
    end
  end
end
