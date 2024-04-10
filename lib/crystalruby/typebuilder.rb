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
