precedence(op::Token) = op.kind < Tokens.end_assignments ? 1 :
                       op.kind < Tokens.end_conditional ? 2 :
                       op.kind < Tokens.end_lazyor ? 3 :
                       op.kind < Tokens.end_lazyand ? 4 :
                       op.kind < Tokens.end_arrow ? 5 :
                       op.kind < Tokens.end_comparison ? 6 :
                       op.kind < Tokens.end_pipe ? 7 :
                       op.kind < Tokens.end_colon ? 8 :
                       op.kind < Tokens.end_plus ? 9 :
                       op.kind < Tokens.end_bitshifts ? 10 :
                       op.kind < Tokens.end_times ? 11 :
                       op.kind < Tokens.end_rational ? 12 :
                       op.kind < Tokens.end_power ? 13 :
                       op.kind < Tokens.end_decl ? 14 : 15

precedence(op::OPERATOR) = op.precedence
precedence(fc::CALL) = fc.name isa OPERATOR ? fc.name.precedence : 0

precedence(x) = 0
