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
                       op < Tfokens.end_rational ? 12 :
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



isunaryop{P,K,D}(op::OPERATOR{P,K,D}) = isunaryop(K)
isunaryop(t::Token) = isunaryop(t.kind)

isunaryop(kind) = kind == Tokens.PLUS ||
                      kind == Tokens.MINUS ||
                      kind == Tokens.NOT ||
                      kind == Tokens.APPROX ||
                      kind == Tokens.ISSUBTYPE ||
                      kind == Tokens.NOT_SIGN ||
                      kind == Tokens.AND ||
                      kind == Tokens.GREATER_COLON ||
                      kind == Tokens.SQUARE_ROOT ||
                      kind == Tokens.CUBE_ROOT ||
                      kind == Tokens.QUAD_ROOT ||
                      kind == Tokens.DECLARATION ||
                      kind == Tokens.EX_OR ||
                      kind == Tokens.COLON

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



function issyntaxcall{P,K}(op::OPERATOR{P,K})
    P == 1 && !(K == Tokens.APPROX) ||
    K == Tokens.RIGHT_ARROW || 
    P == 4 ||
    P == 5 ||
    K == Tokens.ISSUBTYPE ||
    K == Tokens.GREATER_COLON ||
    K == Tokens.COLON ||
    K == Tokens.AND ||
    K == Tokens.DECLARATION ||
    K == Tokens.DOT ||
    K == Tokens.DDDOT ||
    K == Tokens.EX_OR
end
    


issyntaxcall(op) = false


"""
    parse_unary(ps)

Having hit a unary operator at the start of an expression return a call.
"""
function parse_unary{P,K}(ps::ParseState, op::OPERATOR{P,K})
    arg = @precedence ps 14 parse_expression(ps)
    if (op isa OPERATOR{9, Tokens.PLUS} || op isa OPERATOR{9, Tokens.MINUS}) && (arg isa LITERAL{Tokens.INTEGER} || arg isa LITERAL{Tokens.FLOAT})
        arg.span += op.span
        arg.offset = op.offset
        if op isa OPERATOR{9, Tokens.MINUS}
            arg.val = string("-", arg.val)
        end
        return arg
    elseif issyntaxcall(op) && !(op isa OPERATOR{6,Tokens.ISSUBTYPE} || op isa OPERATOR{6,Tokens.GREATER_COLON})
        return EXPR(op, [arg], op.span + arg.span)
    else
        return EXPR(CALL, [op, arg], op.span + arg.span)
    end
end

function parse_unary(ps::ParseState, op::OPERATOR{8,Tokens.COLON})
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords || 
        Tokens.begin_literal < ps.nt.kind < Tokens.end_literal || 
        isoperator(ps.nt.kind) ||
        ps.nt.kind == Tokens.IDENTIFIER
        next(ps)
        arg = INSTANCE(ps)
        return QUOTENODE(arg, arg.span, [])
    elseif closer(ps)
        return op
    else
        arg = @precedence ps 20 parse_expression(ps)
        if arg isa EXPR && arg.head == BLOCK && length(arg.args) == 1
            if (first(arg.args) isa OPERATOR || first(arg.args) isa LITERAL || first(arg.args) isa INSTANCE)
                return QUOTENODE(arg.args[1], arg.span, arg.punctuation)
            end
        end
        return EXPR(QUOTE, [arg], arg.span, [])
    end
end


function parse_unary(ps::ParseState, op::OPERATOR{9,Tokens.EX_OR,false})
    arg = @precedence ps 20 parse_expression(ps)
    return EXPR(op, [arg], op.span + arg.span)
end


# Parse assignments
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{1, Tokens.EQ})
    nextarg = @precedence ps 1-LtoR(1) parse_expression(ps)
    if is_func_call(ret)
        # if !(nextarg isa EXPR && nextarg.head == BLOCK)
            nextarg = EXPR(BLOCK, SyntaxNode[nextarg], nextarg.span)
        # end
        scope = Scope{Tokens.FUNCTION}(get_id(ret), [])
        @scope ps scope _lint_func_sig(ps, ret)
        push!(ps.current_scope.args, scope)
    else
        ps.trackscope && _track_assignment(ps, ret, nextarg)
    end

    return EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
end

function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{1})
    nextarg = @precedence ps 1-LtoR(1) parse_expression(ps)
    return EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
end

# Parse conditionals
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{2})
    start = ps.t.startbyte
    nextarg = @closer ps ifop parse_expression(ps)
    op2 = INSTANCE(next(ps))
    nextarg2 = @precedence ps 2-LtoR(2) parse_expression(ps)
    return EXPR(IF, SyntaxNode[ret, nextarg, nextarg2], ret.span + ps.nt.startbyte - start, INSTANCE[op, op2])
end

# Parse arrows
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{3, Tokens.RIGHT_ARROW})
    nextarg = @precedence ps 3-LtoR(3) parse_expression(ps)
    return EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
end

#  Parse ||
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{4})
    nextarg = @precedence ps 4-LtoR(4) parse_expression(ps)
    return EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
end

#  Parse &&
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{5})
    nextarg = @precedence ps 5-LtoR(5) parse_expression(ps)
    return EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
end


function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{6})
    nextarg = @precedence ps 6-LtoR(6) parse_expression(ps)
    if ret isa EXPR && ret.head==COMPARISON
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.span += op.span + nextarg.span
    elseif ret isa EXPR && ret.head == CALL && ret.args[1] isa OPERATOR{6} && isempty(ret.punctuation)
        ret = EXPR(COMPARISON, SyntaxNode[ret.args[2], ret.args[1], ret.args[3], op, nextarg], ret.args[2].span + ret.args[1].span + ret.args[3].span + op.span + nextarg.span)
    elseif ret isa EXPR && (ret.head isa OPERATOR{6,Tokens.ISSUBTYPE} || ret.head isa OPERATOR{6,Tokens.GREATER_COLON})
        ret = EXPR(COMPARISON, SyntaxNode[ret.args[1], ret.head, ret.args[2], op, nextarg], ret.args[1].span + ret.head.span + ret.args[2].span + op.span + nextarg.span)
    elseif (op isa OPERATOR{6,Tokens.ISSUBTYPE} || op isa OPERATOR{6,Tokens.GREATER_COLON})
        ret = EXPR(op, SyntaxNode[ret, nextarg], ret.span + op.span + nextarg.span)
    else
        ret = EXPR(CALL, SyntaxNode[op, ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end

# Parse ranges
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{8, Tokens.COLON})
    start = ps.t.startbyte
    # if ps.nt.kind == Tokens.END
    #     next(ps)
    #     nextarg = INSTANCE(ps)
    # else
        nextarg = @precedence ps 8-LtoR(8) parse_expression(ps)
    # end
    if ret isa EXPR && ret.head isa OPERATOR{8,Tokens.COLON} && length(ret.args)==2
        push!(ret.punctuation, op)
        push!(ret.args, nextarg)
        ret.span += ps.nt.startbyte-start
    else
        ret = EXPR(op, SyntaxNode[ret, nextarg], ret.span + ps.nt.startbyte - start)
    end
    return ret
end


# Parse chained +
function parse_operator(ps::ParseState, ret::EXPR, op::OPERATOR{9,Tokens.PLUS})
    if ret.head==CALL && ret.args[1] isa OPERATOR{9,Tokens.PLUS,false}
        nextarg = @precedence ps 9-LtoR(9) parse_expression(ps)
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
        push!(ret.punctuation, op)
    else
        ret = invoke(parse_operator, Tuple{ParseState,SyntaxNode,OPERATOR}, ps, ret, op)
    end
    return ret
end

# Parse chained *
function parse_operator(ps::ParseState, ret::EXPR, op::OPERATOR{11,Tokens.STAR})
    if ret.head==CALL && ret.args[1] isa OPERATOR{11,Tokens.STAR,false}
        nextarg = @precedence ps 11-LtoR(11) parse_expression(ps)
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
        push!(ret.punctuation, op)
    else
        ret = invoke(parse_operator, Tuple{ParseState,SyntaxNode,OPERATOR}, ps, ret, op)
    end
    return ret
end

# parse declarations
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{14})
    nextarg = @precedence ps 14-LtoR(14) parse_expression(ps)
    return EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
end

# parse dot access
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{15})
    if ps.nt.kind==Tokens.LPAREN
        start = ps.nt.startbyte
        puncs = INSTANCE[INSTANCE(next(ps))]
        args = @closer ps paren parse_list(ps, puncs)
        push!(puncs, INSTANCE(next(ps)))
        nextarg = EXPR(TUPLE, args, ps.nt.startbyte - start, puncs)
    elseif iskw(ps.nt) || ps.nt.kind == Tokens.IN || ps.nt.kind == Tokens.ISA
        next(ps)
        nextarg = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, ps.t.startbyte, Symbol(lowercase(string(ps.t.kind))))
    elseif ps.nt.kind == Tokens.AT_SIGN
        nextarg = @closer ps ws @precedence ps 15-LtoR(15) parse_expression(ps)
    else
        nextarg = @precedence ps 15-LtoR(15) parse_expression(ps)
    end

    if nextarg isa INSTANCE
        ret = EXPR(op, SyntaxNode[ret, QUOTENODE(nextarg, nextarg.span, [])], op.span + ret.span + nextarg.span)
    else
        ret = EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end


function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{0, Tokens.DDDOT})
    return  EXPR(op, SyntaxNode[ret], op.span + ret.span)
end

function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{20, Tokens.PRIME})
    return  EXPR(op, SyntaxNode[ret], op.span + ret.span)
end

function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{20, Tokens.ANON_FUNC})
    ret = EXPR(op, SyntaxNode[ret], op.span + ret.span - ps.nt.startbyte)
    arg = parse_expression(ps)
    push!(ret.args, EXPR(BLOCK, [arg], arg.span))
    ret.span += ps.nt.startbyte
    return ret
end

function parse_operator{op_prec,K}(ps::ParseState, ret::SyntaxNode, op::OPERATOR{op_prec, K})
    nextarg = @precedence ps op_prec-LtoR(op_prec) parse_expression(ps)
    ret = EXPR(CALL, SyntaxNode[op, ret, nextarg], op.span + ret.span + nextarg.span)
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
