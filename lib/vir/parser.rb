require 'parslet'

module Vir
  class Parser < Parslet::Parser
    rule(:ws) { match('[ \t]').repeat(1) }
    rule(:ws?) { ws.maybe }
    rule(:br) { str("\n") }

    rule(:line_comment_text) { (br.absnt? >> any).repeat }
    rule(:multiline_comment_text) { (str('*/').absnt? >> any).repeat }

    rule(:comment) { 
      str('#') >> line_comment_text.as(:text) |
      str('//') >> line_comment_text.as(:text) |
      str('/*') >> multiline_comment_text.as(:text) >> str('*/')
    }

    # Empty whitespace is any whitespace that has no content of any sort (
    # so unlike iws, it doesn't include comments).
    # Basically, it's whitespace before something really starts.
    rule(:ews) { (ws | br).repeat(1) }
    rule(:ews?) { ews.maybe }

    # Line whitespace is any kind of whitespace on the same line (including comments).
    # Use for stuff that shouldn't go to the next line, but still expects something
    # more to complete the expression (eg. a >> lws >> '+' >> iws >> b)
    rule(:lws) { (ws | comment.as(:inline_doc)).repeat(1) }
    rule(:lws?) { lws.maybe }

    # Inner whitespace is space between elements of the same line.
    # It can include spaces, line breaks, and comments.
    rule(:iws) { (ws | br | comment.as(:inline_doc)).repeat(1) }
    rule(:iws?) { iws.maybe }

    # End of line can be any amount of whitespace, including comments,
    # and ending in either a \n or semicolon
    rule(:eol) { (ws | comment.as(:inline_doc)).repeat >> (br | str(';')) }

    rule(:symbol) {
      match('[a-zA-Z_]') >> match('[a-zA-Z0-9_]').repeat
    }

    rule(:nil_const) {
      str("nil").as(:nil)
    }
    rule(:undef_const) {
      str("undef").as(:undef)
    }
    rule(:true_const) {
      str("true").as(:true)
    }
    rule(:false_const) {
      str("false").as(:false)
    }

    rule(:symbol_const) {
      symbol.as(:symbol)
    }

    rule(:integer_const) {
      match('[0-9]').repeat(1).as(:integer)
    }

    rule(:string_const) {
      (str('"') >> (str('"').absnt? >> any).repeat >> str('"')).as(:string)
    }

    rule(:map_const) {
      (str("{") >> iws? >> (expression.as(:key) >> iws? >> str(':') >> iws? >> expression.as(:value) >> iws? >> str(',').maybe).repeat.as(:entries) >> iws? >> str('}')).as(:map)
    }
    rule(:list_const) {
      (str("[") >> iws? >> (expression >> iws? >> str(",").maybe).repeat.as(:entries) >> iws? >> str("]")).as(:list)
    }

    rule(:const) {
      nil_const | undef_const | true_const | false_const | symbol_const | integer_const | string_const | map_const | list_const
    }

    rule(:local_var) {
      (str('$') >> symbol.as(:name)).as(:local_var)
    }
    rule(:instance_var) {
      (str('@') >> symbol.as(:name)).as(:instance_var)
    }
    rule(:module_var) {
      (str('@@') >> symbol.as(:name)).as(:module_var)
    }
    rule(:instance_self) {
      str('@').as(:self)
    }
    rule(:mod_self) {
      str('@@').as(:mod_self)
    }

    rule(:variable) { # Note: order IS important here.
      (local_var | module_var | instance_var | mod_self | instance_self)
    }

    rule(:prefix_op_expression) {
      ((str('!') | str('+') | str('-') | str('~')).as(:op) >> iws? >> unary_expression).as(:prefix_op)
    }

    rule(:unary_expression) {
      (str('(') >> iws? >> expression >> iws? >> str(')')) |
      prefix_op_expression | const | variable
    }

    rule(:args) {
      (iws? >> expression >> (iws? >> str(',') >> iws? >> expression).repeat).as(:args)
    }

    rule(:arglist) {
      str('(') >> iws? >> args.maybe >> iws? >> str(')')
    }

    rule(:line_statement) {
      statement >> eol
    }
    rule(:tail_statement) {
      statement >> iws?
    }
    rule(:statement_sequence) {
      (ews? >> line_statement).repeat >> ews? >> tail_statement |
      (ews? >> line_statement).repeat(1) |
      ews? >> tail_statement
    }

    rule(:block_arg) {
      (str('**') | str('*') | str('&')).as(:prefix) >> iws? >> symbol.as(:name) >> iws? |
      symbol.as(:name) >> iws? >>
        (str(':') >> iws? >> expression.as(:default) >> iws?).maybe >> 
        (str('as') >> iws? >> expression.as(:type) >> iws?).maybe
    }
    rule(:block_comma_arg) {
      block_arg >> str(',') >> iws?
    }

    rule(:block_args) {
      str('(') >> iws? >> (block_comma_arg.repeat >> block_arg).repeat(0,1).as(:args) >> str(')')
    }

    rule(:block_body) {
      block_args.maybe >> iws? >> str('{') >> eol.maybe >> statement_sequence.repeat(0,1).as(:lines) >> iws? >> str('}')
    }

    rule(:named_block) {
      (unary_expression.as(:name) >> iws? >> str(':') >> iws? >> block_body).as(:block)
    }
    rule(:default_block) {
      (str(':') >> iws? >> block_body).as(:default_block)
    }
    rule(:blocks) {
      (default_block >> lws? >> (named_block >> lws?).repeat) |
      (named_block >> lws?).repeat(1)
    }

    rule(:call_args) {
      arglist >> lws? >> blocks.repeat(0,1).as(:blocks) |
      blocks.repeat(1,1).as(:blocks)
    }

    rule(:call_expression) {
      (((call_expression | unary_expression).as(:on) >> lws? >> str('.') >> iws? >> symbol.as(:name)).as(:ref) >> lws? >> call_args.maybe).as(:call) |
      (symbol.as(:name).as(:ref) >> lws? >> call_args).as(:call) |
      (unary_expression.as(:on).as(:ref) >> lws? >> call_args).as(:call) |
      unary_expression
    }

    rule(:array_index_expression) {
      (call_expression.as(:from) >> (lws? >> str('[') >> iws? >> expression >> iws? >> str(']')).repeat(1).as(:index)).as(:array_op) |
      call_expression
    }

    rule(:product_op_expression) {
      (array_index_expression >> (lws? >> (str('*') | str('/') | str('%')).as(:op) >> iws? >> array_index_expression).repeat(1)).as(:product) |
      array_index_expression
    }

    rule(:sum_op_expression) {
      (product_op_expression >> (lws? >> (str('+') | str('-')).as(:op) >> iws? >> product_op_expression).repeat(1)).as(:sum) |
      product_op_expression
    }

    rule(:bitshift_op_expression) {
      (sum_op_expression >> (lws? >> (str('>>') | str('<<')).as(:op) >> iws? >> sum_op_expression).repeat(1)).as(:bitshift) |
      sum_op_expression
    }

    rule(:relational_op_expression) {
      (bitshift_op_expression >> (lws? >> (str('>') | str('<') | str('<=') | str('>=')).as(:op) >> iws? >> bitshift_op_expression).repeat(1)).as(:relational) |
      bitshift_op_expression
    }

    rule(:equality_op_expression) {
      (relational_op_expression >> (lws? >> (str('==') | str('!=')).as(:op) >> iws? >> relational_op_expression).repeat(1)).as(:equality) |
      relational_op_expression
    }

    rule(:bitwise_op_expression) {
      (equality_op_expression >> (lws? >> (str('&') | str('^') | str('|')).as(:op) >> iws? >> equality_op_expression).repeat(1)).as(:bitwise) |
      equality_op_expression
    }

    rule(:logical_op_expression) {
      (bitwise_op_expression >> (lws? >> (str('&&') | str('||')).as(:op) >> iws? >> bitwise_op_expression).repeat(1)).as(:logical) |
      bitwise_op_expression
    }

    rule(:assignment_expression) {
      (logical_op_expression >> (lws? >> (str('=') | str('+=') | str('-=') | str('*=') | str('/=') | str('%=') | str('&=') | str('^=') | str('|=') | str('<<=') | str('>>=')).as(:op) >> iws? >> bitwise_op_expression).repeat(1)).as(:assign) |
      logical_op_expression
    }

    rule(:expression) {
      assignment_expression
    }

    rule(:statement) {
      ((ews | comment).repeat.as(:doc) >> ws? >> expression).as(:statement)
    }

    # A 'script' in vir always has exactly one statement. The result of this
    # statement is the return value of the script. Usually
    # this statement would be a module or class. It can also be followed by any number of
    # unassociated comments.
    rule(:script) {
      statement >> iws?
    }

    root(:script)
  end
end