module CrystalRuby
  module SourceReader
    module_function

    # Reads code line by line from a given source location and returns the first valid Ruby expression found
    def extract_expr_from_source_location(source_location)
      lines = source_location.then { |f, l| IO.readlines(f)[l - 1..] }
      lines[0] = lines[0][/CRType.*/] if lines[0] =~ /<\s+CRType/ || lines[0] =~ /= CRType/
      lines.each.with_object([]) do |line, expr_source|
        break expr_source.join("") if Prism.parse((expr_source << line).join("")).success?
      end
    rescue StandardError
      raise "Failed to extract expression from source location: #{source_location}. Ensure the file exists and the line number is correct. Extraction from a REPL is not supported"
    end

    def search_node(result, node_type)
      result.breadth_first_search do |node|
        node_type === node
      end
    end

    # Given a proc, extracts the source code of the block passed to it
    # If raw is true, the source is expected to be Raw Crystal code captured
    # in a string or Heredoc literal. Otherwise the Ruby code (assumed to be valid Crystal)
    # is extracted.
    def extract_source_from_proc(block, raw: false)
      block_source = extract_expr_from_source_location(block.source_location)
      parsed_source = Prism.parse(block_source).value

      node = parsed_source.statements.body[0].arguments&.arguments&.find { |x| search_node(x, Prism::StatementsNode) }
      node ||= parsed_source.statements.body[0]
      body_node = search_node(node, Prism::StatementsNode)

      raw ? extract_raw_string_node(body_node) : node_to_s(body_node)
    end

    def extract_raw_string_node(node)
      search_node(node, Prism::InterpolatedStringNode)&.parts&.map do |p|
        p.respond_to?(:unescaped) ? p.unescaped : p.slice
      end&.join("") ||
        search_node(node, Prism::StringNode).unescaped
    end

    # Simple helper function to turn a SyntaxTree node back into a Ruby string
    # The default formatter will turn a break/return of [1,2,3] into a brackless 1,2,3
    # Can't have that in Crystal as it turns it into a Tuple
    def node_to_s(node)
      node&.slice || ""
    end

    # Given a method, extracts the source code of the block passed to it
    # and also converts any keyword arguments given in the method definition as a
    # named map of keyword names to Crystal types.
    # Also supports basic ffi symbol types.
    #
    # E.g.
    #
    # def add a: Int32 | Int64, b: :int
    #
    # The above will be converted to:
    # {
    #   a: Int32 | Int64, # Int32 | Int64 is a Crystal type
    #   b: :int           # :int is an FFI type shorthand
    # }
    # If raw is true, the source is expected to be Raw Crystal code captured
    # in a string or Heredoc literal. Otherwise the Ruby code (assumed to be valid Crystal)
    # is extracted.
    def extract_args_and_source_from_method(method, raw: false)
      method_source = extract_expr_from_source_location(method.source_location)
      parsed_source = Prism.parse(method_source).value
      params = search_node(parsed_source, Prism::ParametersNode)
      args = params ? params.keywords.map { |kw| [kw.name, node_to_s(kw.value)] }.to_h : {}
      body_node = parsed_source.statements.body[0].body
      if body_node.respond_to?(:rescue_clause) && body_node.rescue_clause
        wrapped = %(begin\n#{body_node.statements.slice}\n#{body_node.rescue_clause.slice}\nend)
        body_node = Prism.parse(wrapped).value
      end
      body = raw ? extract_raw_string_node(body_node) : node_to_s(body_node)

      args.transform_values! do |type_exp|
        if CrystalRuby::Typemaps::CRYSTAL_TYPE_MAP.key?(type_exp[1..-1].to_sym)
          type_exp[1..-1].to_sym
        else
          TypeBuilder.build_from_source(type_exp, context: method.owner)
        end
      end.to_h
      [args, body]
    end
  end
end
