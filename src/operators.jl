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


function issyntaxcall(op::String)
    sizeof(op)<=4 && (
    op == "=" ||
    op == "+=" ||
    op == "-=" ||
    op == "*=" ||
    op == "/=" ||
    op == "//=" ||
    op == "|=" ||
    op == "^=" ||
    op == "=" ||
    op == "%=" ||
    op == "<<=" ||
    op == ">>=" ||
    op == ">>>=" ||
    op == "\\=" ||
    op == "&=" ||
    op == ":=" ||
    op == "=>" ||
    op == "\$=" ||
    op == "||" ||
    op == "&&" ||
    op == "<:" ||
    op == ">:" ||
    op == "-->" ||
    op == ":" ||
    op == "&" ||
    op == ".." ||
    op == "::" ||
    op == ".")
end

"""
    parse_unary(ps)

Having hit a unary operator at the start of an expression return a call.
"""
function parse_unary(ps::ParseState)
    op = INSTANCE(ps)
    arg = parse_expression(ps)
    if issyntaxcall(op.val) && !(op.val=="<:" || op.val==">:")
        return EXPR(op, [arg], op.span + arg.span)
    else
        return EXPR(CALL, [op, arg], op.span + arg.span)
    end
end

function parse_operator(ps::ParseState, ret::Expression)
    next(ps)
    if ps.formatcheck && isassignment(ps.t) && ps.lws.val==""
        push!(ps.hints, "add space at $(ps.lws.endbyte)")
    end

    op = INSTANCE(ps)
    op_prec = precedence(ps.t)

    if ret isa EXPR && ret.head==CALL && ret.args[1].val == op.val  && (op.val == "+" || op.val == "*")
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
        push!(ret.punctuation, op)
    elseif op_prec == 2
        start = ps.t.startbyte
        nextarg = @closer ps ifop parse_expression(ps)
        op2 = INSTANCE(next(ps))
        nextarg2 = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(IF, [ret, nextarg, nextarg2], ret.span + ps.t.endbyte - start, [op, op2])
    elseif op.val == ":" 
        start = ps.t.startbyte
        if ps.nt.kind == Tokens.END
            nextarg = INSTANCE(next(ps))
        else
            nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        end
        if ret isa EXPR && ret.head.val == ":" && length(ret.args)==2
            push!(ret.punctuation, op)
            push!(ret.args, nextarg)
            ret.span += ps.ws.endbyte-start
        else
            ret = EXPR(op, [ret, nextarg], ret.span + ps.ws.endbyte - start)
        end
    elseif op_prec == 6 
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        if ret isa EXPR && ret.head==COMPARISON
            push!(ret.args, op)
            push!(ret.args, nextarg)
            ret.span += op.span + nextarg.span
        elseif ret isa EXPR && ret.head == CALL && ret.args[1] isa INSTANCE{OPERATOR{6}}
            ret = EXPR(COMPARISON, [ret.args[2], ret.args[1], ret.args[3], op, nextarg], ret.args[2].span + ret.args[1].span + ret.args[3].span + op.span + nextarg.span)
        elseif ret isa EXPR && (ret.head.val == "<:" || ret.head.val == ">:")
            ret = EXPR(COMPARISON, [ret.args[1], ret.head, ret.args[2], op, nextarg], ret.args[1].span + ret.head.span + ret.args[2].span + op.span + nextarg.span)
        elseif op.val == "<:" || op.val == ">:"
            ret = EXPR(op, [ret, nextarg], ret.span + op.span + nextarg.span)
        else
            ret = EXPR(CALL, [op, ret, nextarg], op.span + ret.span + nextarg.span)
        end
    elseif op_prec==1
        if ps.formatcheck && ps.ws.val==""
            push!(ps.hints, "add space at $(ps.nt.startbyte)")
        end
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        if ret isa EXPR && ret.head == CALL && !(nextarg isa EXPR && nextarg.head == BLOCK)
            nextarg = EXPR(BLOCK, [nextarg], nextarg.span)
        end
        ret = EXPR(op, [ret, nextarg], op.span + ret.span + nextarg.span)
    elseif op_prec==4 || op_prec==5 || op.val=="-->"
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(op, [ret, nextarg], op.span + ret.span + nextarg.span)
    elseif op_prec==14
        if ps.formatcheck && op_prec==1 && ps.ws.val==""
            push!(ps.hints, "add space at $(ps.nt.startbyte)")
        end
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(op, [ret, nextarg], op.span + ret.span + nextarg.span)
    elseif op_prec==15
        if ps.nt.kind==Tokens.LPAREN
            start = ps.nt.startbyte
            puncs = [INSTANCE(next(ps))]
            args = @closer ps paren parse_list(ps, puncs)
            push!(puncs, INSTANCE(next(ps)))
            nextarg = EXPR(TUPLE, args, ps.t.endbyte - start, puncs)
        else
            nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        end

        if nextarg isa INSTANCE
            ret = EXPR(op, [ret, QUOTENODE(nextarg, nextarg.span)], op.span + ret.span + nextarg.span)
        else
            ret = EXPR(op, [ret, nextarg], op.span + ret.span + nextarg.span)
        end
    elseif op.val=="..." || op.val=="'"
        ret = EXPR(op, [ret], op.span + ret.span)
    else
        nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
        ret = EXPR(CALL, [op, ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end
