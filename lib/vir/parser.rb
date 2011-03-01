require 'parslet'

module Vir
  class Parser < Parslet::Parser
    rule(:ws) { match('[ \t]').repeat(1) }
    rule(:ws?) { ws.maybe }
    rule(:br) { str("\n") }
    rule(:all_ws) { (ws | br | comment).repeat }

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
      (str("{") >> ws? >> (expression.as(:key) >> ws? >> str(':') >> ws? >> expression.as(:value) >> ws? >> str(',').maybe).repeat.as(:entries) >> ws? >> str('}')).as(:map)
    }
    rule(:list_const) {
      (str("[") >> ws? >> (expression >> ws? >> str(",").maybe).repeat.as(:entries) >> ws? >> str("]")).as(:list)
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

    rule(:unary_expression) {
      (str('(') >> ws? >> expression >> ws? >> str(')')) |
      prefix_op_expression | const | variable
    }

    rule(:args) {
      (ws? >> expression >> (ws? >> str(',') >> ws? >> expression).repeat).as(:args)
    }

    rule(:arglist) {
      str('(') >> ws? >> args.maybe >> ws? >> str(')')
    }

    rule(:blockbody) {
      str('{') >> all_ws.maybe >> statement.repeat.as(:lines) >> all_ws.maybe >> str('}')
    }

    rule(:block) {
      (expression.as(:name) >> ws? >> match(':') >> ws? >> blockbody).as(:block)
    }

    rule(:call_args) {
      arglist >> ws? >> (block >> ws?).repeat.as(:blocks) |
      (block >> ws?).repeat(1).as(:blocks)
    }

    rule(:call_expression) {
      (((call_expression | unary_expression).as(:on) >> ws? >> str('.') >> ws? >> symbol.as(:name)).as(:ref) >> call_args.maybe).as(:call) |
      (symbol.as(:name).as(:ref) >> ws? >> call_args).as(:call) |
      unary_expression
    }

    rule(:array_index_expression) {
      (call_expression.as(:from) >> (ws? >> str('[') >> ws? >> expression >> ws? >> str(']')).repeat(1).as(:index)).as(:array_op) |
      call_expression
    }

    rule(:product_op_expression) {
      (array_index_expression >> (ws? >> (str('*') | str('/') | str('%')).as(:op) >> ws? >> array_index_expression).repeat(1)).as(:product) |
      array_index_expression
    }

    rule(:sum_op_expression) {
      (product_op_expression >> (ws? >> (str('+') | str('-')).as(:op) >> ws? >> product_op_expression).repeat(1)).as(:sum) |
      product_op_expression
    }

    rule(:bitshift_op_expression) {
      (sum_op_expression >> (ws? >> (str('>>') | str('<<')).as(:op) >> ws? >> sum_op_expression).repeat(1)).as(:bitshift) |
      sum_op_expression
    }

    rule(:relational_op_expression) {
      (bitshift_op_expression >> (ws? >> (str('>') | str('<') | str('<=') | str('>=')).as(:op) >> ws? >> bitshift_op_expression).repeat(1)).as(:relational) |
      bitshift_op_expression
    }

    rule(:bitwise_op_expression) {
      (relational_op_expression >> (ws? >> (str('&') | str('^') | str('|')).as(:op) >> ws? >> relational_op_expression).repeat(1)).as(:bitwise) |
      relational_op_expression
    }

    rule(:logical_op_expression) {
      (bitwise_op_expression >> (ws? >> (str('&&') | str('||')).as(:op) >> ws? >> bitwise_op_expression).repeat(1)).as(:logical) |
      bitwise_op_expression
    }

    rule(:op_expression) {
       logical_op_expression
    }

    rule(:prefix_op_expression) {
      ((str('!') | str('+') | str('-') | str('~')).as(:op) >> ws? >> unary_expression).as(:prefix_op)
    }

    rule(:expression) {
      ws? >> (op_expression | unary_expression)
    }

    rule(:line_comment_text) { (br.absnt? >> any).repeat }
    rule(:multiline_comment_text) { (str('*/').absnt? >> any).repeat }

    rule(:comment) { 
      str('#') >> line_comment_text.as(:text) >> br.maybe |
      str('//') >> line_comment_text.as(:text) >> br.maybe |
      str('/*') >> multiline_comment_text.as(:text) >> str('*/') >> ws? >> br.maybe
    }

    rule(:statement) {
      (comment.repeat.as(:doc) >> ws? >> expression).as(:statement) >> (ws? >> (br | str(';'))).repeat
    }

    # A 'script' in vir always has exactly one statement. The result of this
    # statement is the return value of the script. Usually
    # this statement would be a module or class. It can also be followed by any number of
    # unassociated comments.
    rule(:script) {
      ws? >> statement >> ws? >> comment.repeat
    }

    root(:script)
  end
end