# frozen_string_literal: true

require "json"

module CrystalRuby::Types
  class TypeSerializer
    class JSON < TypeSerializer
      def lib_type
        "UInt8*"
      end

      def crystal_type
        type_expr
      end

      def error_value
        '"{}".to_unsafe'
      end

      def ffi_type
        :string
      end

      def prepare_argument(arg)
        arg.to_json
      end

      def prepare_retval(retval)
        @typedef.interpret!(::JSON.parse(retval))
      end

      def lib_to_crystal_type_expr(expr)
        "(#{type_expr}).from_json(String.new(%s))" % expr
      end

      def crystal_to_lib_type_expr(expr)
        "%s.to_json.to_unsafe" % expr
      end
    end
  end
end
