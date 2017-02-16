precedence(op::Int) = op < Tokens.end_assignments ? 1 :
                       op < Tokens.end_conditional ? 2 :
                       op < Tokens.end_arrow ? 3 :
                       op < Tokens.end_lazyor ? 4 :
                       op < Tokens.end_lazyand ? 5 :
                       op < Tokens.end_comparison ? 6 :
                       op < Tokens.end_pipe ? 7 :
                       op < Tokens.end_colon ? 8 :
                       op < Tokens.end_plus ? 9 :
                       op < Tokens.end_bitshifts ? 10 :
                       op < Tokens.end_times ? 11 :
                       op < Tokens.end_rational ? 12 :
                       op < Tokens.end_power ? 13 :
                       op < Tokens.end_decl ? 14 : 15

precedence(op::Token) = op.kind < Tokens.begin_assignments ? 0 :
                        op.kind < Tokens.end_assignments ? 1 :
                       op.kind < Tokens.end_conditional ? 2 :
                       op.kind < Tokens.end_arrow ? 3 :
                       op.kind < Tokens.end_lazyor ? 4 :
                       op.kind < Tokens.end_lazyand ? 5 :
                       op.kind < Tokens.end_comparison ? 6 :
                       op.kind < Tokens.end_pipe ? 7 :
                       op.kind < Tokens.end_colon ? 8 :
                       op.kind < Tokens.end_plus ? 9 :
                       op.kind < Tokens.end_bitshifts ? 10 :
                       op.kind < Tokens.end_times ? 11 :
                       op.kind < Tokens.end_rational ? 12 :
                       op.kind < Tokens.end_power ? 13 :
                       op.kind < Tokens.end_decl ? 14 : 
                       op.kind < Tokens.end_dot ? 15 : 20

precedence(x) = 0

isoperator(t::Token) = Tokens.begin_ops < t.kind < Tokens.end_ops

isunaryop(t::Token) = t.kind == Tokens.PLUS ||
                      t.kind == Tokens.MINUS ||
                      t.kind == Tokens.NOT ||
                      t.kind == Tokens.APPROX ||
                      t.kind == Tokens.ISSUBTYPE ||
                      t.kind == Tokens.NOT_SIGN ||
                      t.kind == Tokens.AND ||
                      t.kind == Tokens.GREATER_COLON ||
                      t.kind == Tokens.SQUARE_ROOT ||
                      t.kind == Tokens.CUBE_ROOT ||
                      t.kind == Tokens.QUAD_ROOT ||
                      t.kind == Tokens.DECLARATION

isunaryandbinaryop(t::Token) = t.kind == Tokens.PLUS ||
                               t.kind == Tokens.MINUS ||
                               t.kind == Tokens.EX_OR ||
                               t.kind == Tokens.AND ||
                               t.kind == Tokens.APPROX ||
                               t.kind == Tokens.DECLARATION

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



# function issyntaxcall(op::INSTANCE)
#     op isa INSTANCE{OPERATOR{1}} && !(op isa INSTANCE{OPERATOR{1},Tokens.APPROX}) ||
#     op isa INSTANCE{OPERATOR{3},Tokens.RIGHT_ARROW} ||
#     op isa INSTANCE{OPERATOR{4},Tokens.LAZY_OR} ||
#     op isa INSTANCE{OPERATOR{5},Tokens.LAZY_AND} ||
#     op isa INSTANCE{OPERATOR{6},Tokens.ISSUBTYPE} ||
#     op isa INSTANCE{OPERATOR{6},Tokens.GREATER_COLON} ||
#     op isa INSTANCE{OPERATOR{8},Tokens.COLON} ||
#     op isa INSTANCE{OPERATOR{11},Tokens.AND} ||
#     op isa INSTANCE{OPERATOR{14},Tokens.DECLARATION} ||
#     op isa INSTANCE{OPERATOR{15},Tokens.DOT} ||
#     op isa INSTANCE{OPERATOR{20},Tokens.DDDOT}
# end

function issyntaxcall{P,K}(op::OPERATOR{P,K})
    P == 1 && !(K == Tokens.APPROX) ||
    P == 3 && K == Tokens.RIGHT_ARROW || 
    P == 4 ||
    P == 5 ||
    K == Tokens.ISSUBTYPE ||
    K == Tokens.GREATER_COLON ||
    K == Tokens.COLON ||
    K == Tokens.AND ||
    K == Tokens.DECLARATION ||
    K == Tokens.DOT ||
    K == Tokens.DDDOT
end
    


issyntaxcall(op) = false


"""
    parse_unary(ps)

Having hit a unary operator at the start of an expression return a call.
"""
function parse_unary(ps::ParseState, op)
    arg = parse_expression(ps)
    if issyntaxcall(op) && !(op isa OPERATOR{6,Tokens.ISSUBTYPE} || op isa OPERATOR{6,Tokens.GREATER_COLON})
        return EXPR(op, [arg], op.span + arg.span)
    else
        return EXPR(CALL, [op, arg], op.span + arg.span)
    end
end

function parse_operator(ps::ParseState, ret::Expression)
    next(ps)
    format(ps)

    op = INSTANCE(ps)
    op_prec = precedence(ps.t)

    if ret isa EXPR && ret.head==CALL && typeof(ret.args[1]) == typeof(op)  && (op isa OPERATOR{9,Tokens.PLUS} || op isa OPERATOR{11,Tokens.STAR})
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
        push!(ret.punctuation, op)
    elseif op_prec == 2
        start = ps.t.startbyte
        nextarg = @closer ps ifop parse_expression(ps)
        op2 = INSTANCE(next(ps))
        nextarg2 = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(IF, Expression[ret, nextarg, nextarg2], ret.span + ps.ws.endbyte - start + 1, INSTANCE[op, op2])
    elseif op isa OPERATOR{8,Tokens.COLON}
        start = ps.t.startbyte
        if ps.nt.kind == Tokens.END
            nextarg = INSTANCE(next(ps))
        else
            nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        end
        if ret isa EXPR && ret.head isa OPERATOR{8,Tokens.COLON} && length(ret.args)==2
            push!(ret.punctuation, op)
            push!(ret.args, nextarg)
            ret.span += ps.ws.endbyte-start + 1
        else
            ret = EXPR(op, Expression[ret, nextarg], ret.span + ps.ws.endbyte - start + 1)
        end
    elseif op_prec == 6 
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        if ret isa EXPR && ret.head==COMPARISON
            push!(ret.args, op)
            push!(ret.args, nextarg)
            ret.span += op.span + nextarg.span
        elseif ret isa EXPR && ret.head == CALL && ret.args[1] isa OPERATOR{6}
            ret = EXPR(COMPARISON, Expression[ret.args[2], ret.args[1], ret.args[3], op, nextarg], ret.args[2].span + ret.args[1].span + ret.args[3].span + op.span + nextarg.span)
        elseif ret isa EXPR && (ret.head isa OPERATOR{6,Tokens.ISSUBTYPE} || ret.head isa OPERATOR{6,Tokens.GREATER_COLON})
            ret = EXPR(COMPARISON, Expression[ret.args[1], ret.head, ret.args[2], op, nextarg], ret.args[1].span + ret.head.span + ret.args[2].span + op.span + nextarg.span)
        elseif (op isa OPERATOR{6,Tokens.ISSUBTYPE} || op isa OPERATOR{6,Tokens.GREATER_COLON})
            ret = EXPR(op, Expression[ret, nextarg], ret.span + op.span + nextarg.span)
        else
            ret = EXPR(CALL, Expression[op, ret, nextarg], op.span + ret.span + nextarg.span)
        end
    elseif op_prec==1
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        if ret isa EXPR && ret.head == CALL && !(nextarg isa EXPR && nextarg.head == BLOCK)
            nextarg = EXPR(BLOCK, Expression[nextarg], nextarg.span)
        end
        ret = EXPR(op, Expression[ret, nextarg], op.span + ret.span + nextarg.span)
    elseif op_prec==4 || op_prec==5 || op isa OPERATOR{3, Tokens.RIGHT_ARROW}
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(op, Expression[ret, nextarg], op.span + ret.span + nextarg.span)
    elseif op_prec==14
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(op, Expression[ret, nextarg], op.span + ret.span + nextarg.span)
    elseif op_prec==15
        if ps.nt.kind==Tokens.LPAREN
            start = ps.nt.startbyte
            puncs = INSTANCE[INSTANCE(next(ps))]
            args = @closer ps paren parse_list(ps, puncs)
            push!(puncs, INSTANCE(next(ps)))
            nextarg = EXPR(TUPLE, args, ps.ws.endbyte - start + 1, puncs)
        else
            nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        end

        if nextarg isa INSTANCE
            ret = EXPR(op, Expression[ret, QUOTENODE(nextarg, nextarg.span, [])], op.span + ret.span + nextarg.span)
        else
            ret = EXPR(op, Expression[ret, nextarg], op.span + ret.span + nextarg.span)
        end
    elseif op isa OPERATOR{20,Tokens.DDDOT} || op isa OPERATOR{20,Tokens.PRIME}
        ret = EXPR(op, Expression[ret], op.span + ret.span)
    else
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(CALL, Expression[op, ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end

function next(x::EXPR, s::Iterator{:op})
    if length(x.args) == 2
        if s.i==1
            return x.args[1], +s
        elseif s.i==2
            return x.args[2], +s
        end
    else
        if s.i==1
            return x.args[2], +s
        elseif s.i==2
            return x.args[1], +s
        elseif s.i==3 
            return x.args[3], +s
        end
    end
end

function next(x::EXPR, s::Iterator{:opchain})
    if isodd(s.i)
        return x.args[div(s.i+1,2)+1], +s
    elseif s.i == 2
        return x.args[1], +s
    else 
        return x.punctuation[div(s.i, 2)-1], +s
    end
end

function next(x::EXPR, s::Iterator{:syntaxcall})
    if s.i==1
        return x.args[1], +s
    elseif s.i==2
        return x.head, +s
    elseif s.i==3 
        return x.args[2], +s
    end
end


function next(x::EXPR, s::Iterator{:(:)})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2
        return x.head, +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    elseif s.i == 5 
        return x.args[3], +s
    end
end

function next(x::EXPR, s::Iterator{:?})
    if s.i == 1
        return x.args[1], +s
    elseif s.i == 2 
        return x.punctuation[1], +s
    elseif s.i == 3
        return x.args[2], +s
    elseif s.i == 4 
        return x.punctuation[2], +s
    elseif s.i == 5
        return x.args[3], +s
    end 
end

function next(x::EXPR, s::Iterator{:comparison})
    return x.args[s.i], +s
end
