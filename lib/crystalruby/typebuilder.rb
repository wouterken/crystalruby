require_relative "types"

module CrystalRuby
  module TypeBuilder
    module_function

    def with_injected_type_dsl(context, &block)
      with_constants(context) do
        with_methods(context, &block)
      end
    end

    def with_methods(context)
      restores = []
      %i[Array Hash NamedTuple Tuple].each do |method_name|
        old_method = begin
          context.instance_method(method_name)
        rescue StandardError
          nil
        end
        restores << [context, method_name, old_method]
        context.define_singleton_method(method_name) do |*args|
          Types.send(method_name, *args)
        end
      end
      yield
    ensure
      restores.each do |context, method_name, old_method|
        context.define_singleton_method(method_name, old_method) if old_method
      end
    end

    def with_constants(context)
      previous_const_pairs = CrystalRuby::Types.constants.map do |type|
        [type, begin
          context.const_get(type)
        rescue StandardError
          nil
        end]
      end
      CrystalRuby::Types.constants.each do |type|
        begin
          context.send(:remove_const, type)
        rescue StandardError
          nil
        end
        context.const_set(type, CrystalRuby::Types.const_get(type))
      end
      yield
    ensure
      previous_const_pairs.each do |const_name, const_value|
        begin
          context.send(:remove_const, const_name)
        rescue StandardError
          nil
        end
        context.const_set(const_name, const_value)
      end
    end

    def build
      result = yield
      Types::Type.validate!(result)
      Types::Typedef(result)
    end
  end
end

# class UnionType
#   attr_reader :inner

#   def initialize(*inner)
#     @inner = inner
#   end

#   def |(other)
#     UnionType.new(*inner, *other.inner)
#   end

#   def inspect
#     elements = inner.map(&:inspect).join(" | ")
#   end
# end

# class Type
#   attr_reader :inner, :contains

#   def initialize(name)
#     @name = name
#     @contains = contains
#     @inner = [self]
#   end

#   def |(other)
#     UnionType.new(*inner, *other.inner)
#   end

#   def inspect
#     if @contains
#       "#{@name}(#{@contains.inspect})"
#     else
#       @name
#     end
#   end
# end

# module_function

# %w[
#   Bool Uint8 Uint16 Uint32 Uint64 Int8 Int16 Int32 Int64 Float32 Float64 String Time Symbol
#   Null
# ].map do |t|
#   cls = Class.new(Type)
#   const_set(t, cls)
#   define_method(t.downcase) do
#     cls.new(t)
#   end
# end

# def build(&blk)
#   instance_exec(&blk)
# end

# def hash(key_type, value_type)
#   Hash.new(key_type, value_type)
# end

# def array(type)
#   Array.new(type)
# end

# def tuple(*types)
#   Tuple.new(*types)
# end

# def named_tuple(type_hash)
#   NamedTuple.new(type_hash)
# end

# def NamedTuple(type_hash)
#   NamedTuple.new(type_hash)
# end

# class Hash < Type
#   HASH_KEY_TYPES = %w[String Symbol].freeze
#   def initialize(key_type, value_type)
#     super("Hash")
#     @key_type = key_type
#     @value_type = value_type
#     raise "Invalid key type" unless [Uint8, Uint16, Uint32, Uint64, Int8, Int16, Int32, Int64,
#                                      String].include?(key_type)
#     raise "Invalid value type" unless value_type.is_a?(Type)
#   end
# end

# class Array < Type
#   def initialize(value_type)
#     super("Array")
#     @value_type = value_type
#     raise "Invalid value type" unless value_type.is_a?(Type)
#   end
# end

# class NamedTuple < Type
#   def initialize(types_hash)
#     raise "keys must be symbols" unless types_hash.keys.all? { |k| k.is_a?(Symbol) }
#     raise "Invalid value type" unless types_hash.values.all? { |v| v.is_a?(Type) }

#     super("NamedTuple")
#     @types_hash = types_hash
#   end
# end

# class Tuple < Type
#   def initialize(*value_types)
#     super("Tuple")
#     raise "Invalid value type" unless value_types.all? { |v| v.is_a?(Type) }
#   end
# end
