# frozen_string_literal: true

# Can create complex structs in Ruby
# E.g.
# Types::MyType.new({a: 1, b: [2,3, {four: "five"}})
#
# Can read complex structs in Crystal.
# Expose Ruby setters to Crystal.
#   - These accepts pointers and *copy* the values from them (so that they are governed by Ruby GC)
#   - Safe to GC on Crystal side after call to setter
#
# All Structs are memory managed in Ruby.
# Parameters are temporarily stored in memory *before* being passed, then nilled (might be GC'd if we don't hold on to it elsewhere)
# Internal pointers are stored in complex types.
# Cannot create new structs in Crystal.
# All information passed from Crystal back to Ruby is either:
# - Direct memory access (for primitives)
# - Using setters + copy
#
# What if:
#   - We ask Crystal to implement allocation og memory, and implement all of the setters
#   - It stores the pointers to the memory in an address indexed hash
#   - Ruby will reference count using AutoPointer
#   - If reference count is 0, clear out hash in Crystal (Trigger GC)
#   - Don't like this because, types can't stand alone in Ruby AND crosses FFI bridge many times to allocate complex struct.

require "forwardable"

module CrystalRuby
  InvalidCastError = Class.new(StandardError)

  module Types
    class Type
      # TODO: Replace with pthread primitives and share
      # with Crystal
      ARC_MUTEX = CrystalRuby::ArcMutex.new

      include Allocator
      extend Typemaps

      class << self
        attr_accessor :typename, :ffi_type, :memsize, :convert_if, :inner_types
      end

      def_delegators :@class, :primitive?, :cast!, :type, :typename, :memsize, :refsize,
                     :ffi_type, :error, :inner_type, :inner_keys, :inner_types,
                     :write_mixed_byte_slices_to_uint8_array, :data_offset, :size_offset,
                     :union_types

      attr_accessor :value, :memory

      def initialize(_rbval)
        @class = self.class
        raise error if error
      end

      def self.finalize(_memory)
        ->(_) {}
      end

      def self.inspect_name
        (name || "#{typename}").to_s.gsub(/^CrystalRuby::Types::[^::]+::/, "")
      end

      def self.union_types
        [self]
      end

      def self.valid?
        true
      end

      def self.native_type_expr
        if !inner_types
          "::#{typename}"
        elsif !inner_keys
          "::#{typename}(#{inner_types.map(&:native_type_expr).join(", ")})"
        else
          "::#{typename}(#{inner_keys.zip(inner_types).map { |k, v| "#{k}: #{v.native_type_expr}" }.join(", ")})"
        end
      end

      def self.valid_cast?(raw)
        raw.is_a?(self) || convert_if.any? { |type| raw.is_a?(type) }
      end

      def self.[](*value)
        is_list_type = ancestors.any? { |a| a < CrystalRuby::Types::Array || a < CrystalRuby::Types::Tuple }
        new(is_list_type ? value : value.first)
      end

      def self.anonymous?
        name.nil? || name.start_with?("CrystalRuby::Types::")
      end

      def self.crystal_class_name
        name || native_type_expr.split(",").join("_and_")
                                .split("|").join("_or_")
                                .split("(").join("_of_")
                                .gsub(/[^a-zA-Z0-9_]/, "")
                                .split("_")
                                .map(&:capitalize).join << "_#{type_digest[0..6]}"
      end

      def self.base_crystal_class_name
        crystal_class_name.split("::").last
      end

      def value(native: false)
        @value
      end

      def native
        value(native: true)
      end

      def self.type_digest
        Digest::MD5.hexdigest(native_type_expr.to_s)
      end

      def self.nested_types
        [self, *(inner_types || []).map(&:nested_types)].flatten.uniq
      end

      def self.pointer_to_crystal_type_conversion(expr)
        anonymous? ? "#{crystal_class_name}.new(#{expr}).native" : "#{crystal_class_name}.new(#{expr})"
      end

      def self.crystal_type_to_pointer_type_conversion(expr)
        anonymous? ? "#{crystal_class_name}.new(#{expr}).return_value" : "#{expr}.return_value"
      end

      def self.template_name
        typename || superclass.template_name
      end

      def self.type_defn
        unless Template.const_defined?(template_name) && Template.const_get(template_name).is_a?(Template::Renderer)
          raise "Template not found for #{template_name}"
        end

        Template.const_get(template_name).render(binding)
      end

      def self.numeric?
        false
      end

      def self.primitive?
        false
      end

      def self.variable_width?
        false
      end

      def self.fixed_width?
        false
      end

      def self.cast!(value)
        value.is_a?(Type) ? value.value : value
      end

      def ==(other)
        value(native: true) == (other.is_a?(Type) ? other.value(native: true) : other)
      end

      def nil?
        value.nil?
      end

      def coerce(other)
        [other, value]
      end

      def inspect
        value.inspect
      end

      def self.from_ffi_array_repr(value)
        anonymous? ? new(value).value : new(value)
      end

      def inner_value
        @value
      end

      # Create a brand new copy of this object
      def deep_dup
        self.class.new(native)
      end

      # Create a new reference to this object.
      def dup
        self.class.new(@memory)
      end

      def method_missing(method, *args, &block)
        v = begin
          native
        rescue StandardError
          super
        end
        if v.respond_to?(method)
          hash_before = v.hash
          result = v.send(method, *args, &block)
          if v.hash != hash_before
            self.value = v
            v.equal?(result) ? self : result
          else
            result
          end
        else
          super
        end
      end

      def self.bind_local_vars!(variable_names, binding)
        variable_names.each do |name|
          define_singleton_method(name) do
            binding.local_variable_get("#{name}")
          end
          define_method(name) do
            binding.local_variable_get("#{name}")
          end
        end
      end

      def self.each_child_address(pointer); end

      def item_size
        inner_types.map(&:memsize).sum
      end

      def self.crystal_type
        lib_type(ffi_type)
      end

      def self.|(other)
        raise "Cannot union non-crystal type #{other}" unless other.is_a?(Class) && other.ancestors.include?(Type)

        CrystalRuby::Types::TaggedUnion(*union_types, *other.union_types)
      end

      def self.validate!(type)
        unless type.is_a?(Class) && type.ancestors.include?(Types::Type)
          raise "Result #{type} is not a valid CrystalRuby type"
        end

        raise "Invalid type: #{type.error}" unless type.valid?
      end

      def self.inner_type
        inner_types.first
      end

      def self.type_expr
        if !inner_types
          inspect_name
        elsif !anonymous?
          name
        elsif inner_keys
          "#{inspect_name}(#{inner_keys.zip(inner_types).map { |k, v| "#{k}: #{v.inspect}" }.join(", ")})"
        else
          "#{inspect_name}(#{inner_types.map(&:inspect).join(", ")})"
        end
      end

      def self.inspect
        type_expr
      end
    end
  end
end
