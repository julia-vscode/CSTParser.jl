precedence(op::Int) = op < Tokens.end_assignments ? 1 :
                       op < Tokens.end_conditional ? 2 :
                       op < Tokens.end_lazyor ? 3 :
                       op < Tokens.end_lazyand ? 4 :
                       op < Tokens.end_arrow ? 5 :
                       op < Tokens.end_comparison ? 6 :
                       op < Tokens.end_pipe ? 7 :
                       op < Tokens.end_colon ? 8 :
                       op < Tokens.end_plus ? 9 :
                       op < Tokens.end_bitshifts ? 10 :
                       op < Tokens.end_times ? 11 :
                       op < Tokens.end_rational ? 12 :
                       op < Tokens.end_power ? 13 :
                       op < Tokens.end_decl ? 14 : 15

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

precedence(x) = 0

isoperator(t::Token) = Tokens.begin_ops < t.kind < Tokens.end_ops

isunaryop(t::Token) = t.kind == Tokens.PLUS ||
                      t.kind == Tokens.MINUS ||
                      t.kind == Tokens.NOT ||
                      t.kind == Tokens.APPROX ||
                      t.kind == Tokens.ISSUBTYPE ||
                      t.kind == Tokens.NOT_SIGN ||
                      t.kind == Tokens.GREATER_COLON ||
                      t.kind == Tokens.SQUARE_ROOT ||
                      t.kind == Tokens.CUBE_ROOT ||
                      t.kind == Tokens.QUAD_ROOT

isunaryandbinaryop(t::Token) = t.kind == Tokens.PLUS ||
                               t.kind == Tokens.MINUS ||
                               t.kind == Tokens.EX_OR ||
                               t.kind == Tokens.AND ||
                               t.kind == Tokens.APPROX

isbinaryop(t::Token) = isoperator(t) && 
                    !(t.kind == Tokens.SQUARE_ROOT || 
                    t.kind == Tokens.CUBE_ROOT || 
                    t.kind == Tokens.QUAD_ROOT || 
                    t.kind == Tokens.APPROX || 
                    t.kind == Tokens.NOT || 
                    t.kind == Tokens.NOT_SIGN)

isassignment(t::Token) = Tokens.begin_assignments < t.kind < Tokens.end_assignments

isconditional(t::Token) = t.kind = Tokens.CONDITIONAL

isarrow(t::Token) = Tokens.begin_arrow < t.kind < Tokens.end_arrow

iscomparison(t::Token) = Tokens.begin_comparison < t.kind < Tokens.end_comparison

isplus(t::Token) = Tokens.begin_plus < t.kind < Tokens.end_plus

istimes(t::Token) = Tokens.begin_times < t.kind < Tokens.end_times

ispower(t::Token) = Tokens.begin_power < t.kind < Tokens.end_power

function parse_unary(ps::ParseState)
    op = INSTANCE(ps)
    arg = parse_expression(ps, closer_no_ops(20))
    CHAIN{20}(op.start, arg.stop, [op, arg])
end

function parse_operator(ps::ParseState, ret::Expression)
    next(ps)
    op = INSTANCE(ps)
    op_prec = precedence(ps.t)
    
    if op_prec == 2 # closes on (ws,:)
        nextarg = parse_expression(ps, ps->closer_default(ps) || (isoperator(ps.nt) && precedence(ps.nt)<=1) || (isoperator(ps.nt) && ps.nt.val==":"))
    else
        nextarg = parse_expression(ps, closer_no_ops(op_prec-LtoR(op_prec)))
    end


    if ret isa CHAIN && ret.args[2].val == op.val  && (op.val == "+" || op.val == "*")
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.stop = nextarg.stop
    elseif op.val == ":"
        if ret isa CHAIN && ret.args[2].val == ":" && length(ret.args)==3
            push!(ret.args, op)
            push!(ret.args, nextarg)
            ret.stop = nextarg.stop
        else
            ret = CHAIN{op_prec}(ret.start, nextarg.stop, [ret, op, nextarg])
        end
    elseif op_prec == 6 && ret isa CHAIN{6}
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.stop = nextarg.stop
    elseif op_prec == 2
        op2 = INSTANCE(next(ps))
        nextarg2 = parse_expression(ps, closer_no_ops(op_prec-LtoR(op_prec)))
        ret = CHAIN{op_prec}(ret.start, nextarg2.stop, [ret, op, nextarg, op2, nextarg2])

    else
        ret = CHAIN{op_prec}(ret.start, nextarg.stop, [ret, op, nextarg])
    end
    return ret
end