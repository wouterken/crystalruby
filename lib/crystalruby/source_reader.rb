module CrystalRuby
  module SourceReader
    module_function

    # Reads code line by line from a given source location and returns the first valid Ruby expression found
    def extract_expr_from_source_location(source_location)
      lines = source_location.then{|f,l| IO.readlines(f)[l-1..]}
      lines[0] = lines[0][/CRType.*/] if lines[0] =~ /<\s+CRType/ || lines[0] =~ /= CRType/
      lines.each.with_object("") do |line, expr_source|
        break expr_source if (SyntaxTree.parse(expr_source << line) rescue nil)
      end
    rescue
      raise "Failed to extract expression from source location: #{source_location}. Ensure the file exists and the line number is correct. Extraction from a REPL is not supported"
    end

    # Given a proc, extracts the source code of the block passed to it
    # If raw is true, the source is expected to be Raw Crystal code captured
    # in a string or Heredoc literal. Otherwise the Ruby code (assumed to be valid Crystal)
    # is extracted.
    def extract_source_from_proc(block, raw: false)
      block_source = extract_expr_from_source_location(block.source_location)
      body_node =  SyntaxTree.search(block_source, :Statements).to_a[1]
      return raw ?
        SyntaxTree.search(node_to_s(body_node), :TStringContent).map(&method(:node_to_s)).join :
        node_to_s(body_node)
    end

    @visitor = SyntaxTree::MutationVisitor.new

    # Specify that it should mutate If nodes with assignments in their predicates
    @visitor.mutate("ReturnNode") do |node|
      node
    end

    # Simple helper function to turn a SyntaxTree node back into a Ruby string
    # The default formatter will turn a break/return of [1,2,3] into a brackless 1,2,3
    # Can't have that in Crystal as it turns it into a Tuple
    def node_to_s(node)
      @_syxt_transform ||= SyntaxTree::FlowControlFormatter.prepend(Module.new do
        def format(quer)
          first_arg = self.node.arguments.child_nodes
          if first_arg[0].kind_of?(SyntaxTree::ArrayLiteral)
            return format_arguments(quer, " [", "]")
          end
          super(quer)
        end
      end)
      SyntaxTree::Formatter.format("", node.accept(@visitor))
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
      params = SyntaxTree.search(method_source, :Params).first
      args = params ? params.keywords.map{|k,v| [k.value[0...-1].to_sym, node_to_s(v)] }.to_h : {}
      body_node = SyntaxTree.search(method_source, :BodyStmt).first || SyntaxTree.search(method_source, :Statements).to_a[1]
      body = node_to_s(body_node)
      body = SyntaxTree.search(body, :TStringContent).map(&method(:node_to_s)).join if raw
      args.transform_values! do |type_exp|
        if CrystalRuby::Typemaps::CRYSTAL_TYPE_MAP.key?(type_exp[1..-1].to_sym)
          type_exp[1..-1].to_sym
        else
          TypeBuilder.build_from_source(type_exp, context: method.owner)
        end
      end.to_h
      return args, body
    end

  end
end
