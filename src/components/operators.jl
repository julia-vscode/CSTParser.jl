
precedence(op::Int) = op < Tokens.end_assignments ?  1 :
                       op < Tokens.end_conditional ? 2 :
                       op < Tokens.end_arrow ?       3 :
                       op < Tokens.end_lazyor ?      4 :
                       op < Tokens.end_lazyand ?     5 :
                       op < Tokens.end_comparison ?  6 :
                       op < Tokens.end_pipe ?        7 :
                       op < Tokens.end_colon ?       8 :
                       op < Tokens.end_plus ?        9 :
                       op < Tokens.end_bitshifts ?   10 :
                       op < Tokens.end_times ?       11 :
                       op < Tokens.end_rational ?    12 :
                       op < Tokens.end_power ?       13 :
                       op < Tokens.end_decl ?        14 :
                       op < Tokens.end_where ?       15 : 16

precedence(kind::Tokens.Kind) = kind == Tokens.DDDOT ? DddotOp :
                        kind < Tokens.begin_assignments ? 0 :
                        kind < Tokens.end_assignments ?   1 :
                       kind < Tokens.end_conditional ?    2 :
                       kind < Tokens.end_arrow ?          3 :
                       kind < Tokens.end_lazyor ?         4 :
                       kind < Tokens.end_lazyand ?        5 :
                       kind < Tokens.end_comparison ?     6 :
                       kind < Tokens.end_pipe ?           7 :
                       kind < Tokens.end_colon ?          8 :
                       kind < Tokens.end_plus ?           9 :
                       kind < Tokens.end_bitshifts ?      10 :
                       kind < Tokens.end_times ?          11 :
                       kind < Tokens.end_rational ?       12 :
                       kind < Tokens.end_power ?          13 :
                       kind < Tokens.end_decl ?           14 :
                       kind < Tokens.end_where ?          15 :
                       kind < Tokens.end_dot ?            16 :
                       kind == Tokens.ANON_FUNC ? AnonFuncOp :
                       kind == Tokens.PRIME ?             16 : 20

precedence(x) = 0
precedence(x::AbstractToken) = precedence(x.kind)
precedence(x::OPERATOR) = precedence(x.kind)


isoperator(kind) = Tokens.begin_ops < kind < Tokens.end_ops
isoperator(t::AbstractToken) = isoperator(t.kind)


isunaryop(op::OPERATOR) = isunaryop(op.kind)
isunaryop(t::AbstractToken) = isunaryop(t.kind)

isunaryop(kind) = kind == Tokens.ISSUBTYPE ||
                  kind == Tokens.ISSUPERTYPE ||
                  kind == Tokens.PLUS ||
                  kind == Tokens.MINUS ||
                  kind == Tokens.NOT ||
                  kind == Tokens.APPROX ||
                  kind == Tokens.NOT_SIGN ||
                  kind == Tokens.AND ||
                  kind == Tokens.SQUARE_ROOT ||
                  kind == Tokens.CUBE_ROOT ||
                  kind == Tokens.QUAD_ROOT ||
                  kind == Tokens.DECLARATION ||
                  kind == Tokens.EX_OR ||
                  kind == Tokens.COLON


isunaryandbinaryop(t::AbstractToken) = isunaryandbinaryop(t.kind)
isunaryandbinaryop(kind) = kind == Tokens.PLUS ||
                           kind == Tokens.MINUS ||
                           kind == Tokens.EX_OR ||
                           kind == Tokens.ISSUBTYPE ||
                           kind == Tokens.ISSUPERTYPE ||
                           kind == Tokens.AND ||
                           kind == Tokens.APPROX ||
                           kind == Tokens.DECLARATION ||
                           kind == Tokens.COLON

isbinaryop(op::OPERATOR) = isbinaryop(op.kind)
isbinaryop(t::AbstractToken) = isbinaryop(t.kind)
isbinaryop(kind) = isoperator(kind) &&
                    !(kind == Tokens.SQUARE_ROOT ||
                    kind == Tokens.CUBE_ROOT ||
                    kind == Tokens.QUAD_ROOT ||
                    kind == Tokens.NOT ||
                    kind == Tokens.NOT_SIGN)

isassignment(t::AbstractToken) = Tokens.begin_assignments < t.kind < Tokens.end_assignments

function non_dotted_op(t::AbstractToken)
    k = t.kind
    return (k == Tokens.COLON_EQ ||
            k == Tokens.PAIR_ARROW ||
            k == Tokens.EX_OR_EQ ||
            k == Tokens.CONDITIONAL ||
            k == Tokens.LAZY_OR ||
            k == Tokens.LAZY_AND ||
            k == Tokens.ISSUBTYPE ||
            k == Tokens.ISSUPERTYPE ||
            k == Tokens.LPIPE ||
            k == Tokens.RPIPE ||
            k == Tokens.EX_OR ||
            k == Tokens.COLON ||
            k == Tokens.DECLARATION ||
            k == Tokens.IN ||
            k == Tokens.ISA ||
            k == Tokens.WHERE ||
            (isunaryop(k) && !isbinaryop(k) && !(k == Tokens.NOT)))
end


issyntaxcall(op) = false
function issyntaxcall(op::OPERATOR)
    K = op.kind
    P = precedence(K)
    P == 1 && !(K == Tokens.APPROX || K == Tokens.PAIR_ARROW) ||
    K == Tokens.RIGHT_ARROW ||
    P == 4 ||
    P == 5 ||
    K == Tokens.ISSUBTYPE ||
    K == Tokens.ISSUPERTYPE ||
    K == Tokens.COLON ||
    K == Tokens.DECLARATION ||
    K == Tokens.DOT ||
    K == Tokens.DDDOT ||
    K == Tokens.PRIME ||
    K == Tokens.WHERE
end


issyntaxunarycall(op) = false
function issyntaxunarycall(op::OPERATOR)
    K = op.kind
    !op.dot && (K == Tokens.EX_OR ||
    K == Tokens.AND ||
    K == Tokens.DECLARATION ||
    K == Tokens.ISSUBTYPE ||
    K == Tokens.ISSUPERTYPE)
end



LtoR(prec::Int) = AssignmentOp ≤ prec ≤ LazyAndOp || prec == PowerOp


"""
    parse_unary(ps)

Having hit a unary operator at the start of an expression return a call.
"""
function parse_unary(ps::ParseState, op)
    K,dot = op.kind, op.dot
    if is_colon(op)
        return parse_unary_colon(ps, op)
    elseif (is_plus(op) || is_minus(op)) && (ps.nt.kind ==  Tokens.INTEGER || ps.nt.kind == Tokens.FLOAT) && isemptyws(ps.ws)
        arg = LITERAL(next(ps))
        return LITERAL(op.fullspan + arg.fullspan, first(arg.span):(last(arg.span) + length(op.span)), string(is_plus(op) ? "+" : "-" , val(ps.t, ps)), ps.t.kind)
        return arg
    end

    # Parsing
    P = precedence(K)
    prec = P == DeclarationOp ? DeclarationOp :
                K == Tokens.AND ? 14 :
                K == Tokens.EX_OR ? 20 : 13
    @catcherror ps arg = @precedence ps prec parse_expression(ps)

    if issyntaxunarycall(op)
        ret = UnarySyntaxOpCall(op, arg)
    else
        ret = UnaryOpCall(op, arg)
    end
    return ret
end

function parse_unary_colon(ps::ParseState, op)
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords
        return EXPR{Quotenode}(Any[op, IDENTIFIER(next(ps))])
    elseif Tokens.begin_literal < ps.nt.kind < Tokens.end_literal ||
        isoperator(ps.nt.kind) ||
        ps.nt.kind == Tokens.IDENTIFIER
        return EXPR{Quotenode}(Any[op, INSTANCE(next(ps))])
    elseif closer(ps)
        return op
    else
        # Parsing
        @catcherror ps arg = @precedence ps 20 parse_expression(ps)
        return EXPR{Quote}(Any[op, arg])
    end
end

# Parse assignments
function parse_operator_eq(ps::ParseState, ret, op)
    # Parsing
    @catcherror ps nextarg = @precedence ps AssignmentOp - LtoR(AssignmentOp) parse_expression(ps)

    if is_func_call(ret)
        # Construction
        # NOTE: prior to v"0.6.0-dev.2360" (PR #20076), there was an issue w/ scheme parser
        if VERSION > v"0.6.0-dev.2360" || (!((ret isa BinarySyntaxOpCall && is_decl(ret.op)) && (ret <: Union{UnaryOpCall,UnarySyntaxOpCall,BinaryOpCall,BinarySyntaxOpCall} || length(ret.args) > 1)) && ps.closer.precedence != 0)
            nextarg = EXPR{Block}(Any[nextarg])
        end
    end
    
    return BinarySyntaxOpCall(ret, op, nextarg)
end

# Parse conditionals
function parse_operator_cond(ps::ParseState, ret, op)
    @catcherror ps nextarg = @closer ps ifop parse_expression(ps)
    @catcherror ps op2 = OPERATOR(next(ps))
    @catcherror ps nextarg2 = @closer ps comma @precedence ps 0 parse_expression(ps)

    return ConditionalOpCall(ret, op, nextarg, op2, nextarg2)
end

# Parse comparisons
function parse_comp_operator(ps::ParseState, ret, op)
    @catcherror ps nextarg = @precedence ps ComparisonOp - LtoR(ComparisonOp) parse_expression(ps)
    if ret isa EXPR{Comparison}
        push!(ret, op)
        push!(ret, nextarg)
    elseif ret isa BinaryOpCall && precedence(ret.op) == ComparisonOp
        ret = EXPR{Comparison}(Any[ret.arg1, ret.op, ret.arg2, op, nextarg])
    elseif ret isa BinarySyntaxOpCall && (is_issubt(ret.op) || is_issupt(ret.op))
        ret = EXPR{Comparison}(Any[ret.arg1, ret.op, ret.arg2, op, nextarg])
    elseif (is_issubt(op) || is_issupt(op))
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    else
        ret = BinaryOpCall(ret, op, nextarg)
    end
    return ret
end

# Parse ranges
function parse_operator_colon(ps::ParseState, ret, op)
    @catcherror ps nextarg = @precedence ps ColonOp - LtoR(ColonOp) parse_expression(ps)
    if ret isa BinarySyntaxOpCall && is_colon(ret.op)
        ret = EXPR{ColonOpCall}(Any[ret.arg1, ret.op, ret.arg2])
        push!(ret, op)
        push!(ret, nextarg)
    else
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    end
    return ret
end




# Parse power (special case for preceding unary ops)
function parse_operator_power(ps::ParseState, ret, op)
    @catcherror ps nextarg = @precedence ps PowerOp - LtoR(PowerOp) @closer ps inwhere parse_expression(ps)

    # Construction
    # NEEDS FIX
    if ret isa UnaryOpCall
        if false
            xx = EXPR{InvisBrackets}(Any[ret])
            nextarg = BinaryOpCall(op, xx, nextarg)
        else
            nextarg = BinaryOpCall(ret.arg, op, nextarg)
        end
        ret = UnaryOpCall(ret.op, nextarg)
    else
        ret = BinaryOpCall(ret, op, nextarg)
    end
    return ret
end


# parse where
function parse_operator_where(ps::ParseState, ret, op)
    args = Any[]
    if ps.nt.kind == Tokens.LBRACE
        next(ps)
        push!(args, PUNCTUATION(ps))
        @nocloser ps inwhere while ps.nt.kind != Tokens.RBRACE
            @catcherror ps a = @default ps @nocloser ps newline @closer ps comma @closer ps brace parse_expression(ps)
            push!(args, a)
            if ps.nt.kind == Tokens.COMMA
                push!(args, PUNCTUATION(next(ps)))
            end
        end
        push!(args, PUNCTUATION(next(ps)))
    else
        @catcherror ps nextarg = @precedence ps 5 @closer ps inwhere parse_expression(ps)
        push!(args, nextarg)
    end
    return WhereOpCall(ret, op, args)
end

# parse dot access
function parse_operator_dot(ps::ParseState, ret, op)
    if ps.nt.kind == Tokens.LPAREN
        @catcherror ps sig = @default ps @closer ps paren parse_call(ps, ret)
        args = EXPR{TupleH}(sig.args[2:end])
        ret = BinarySyntaxOpCall(ret, op, args)
        return ret
    elseif iskw(ps.nt) || ps.nt.kind == Tokens.IN || ps.nt.kind == Tokens.ISA || ps.nt.kind == Tokens.WHERE
        nextarg = IDENTIFIER(next(ps))
    elseif ps.nt.kind == Tokens.COLON
        op2 = OPERATOR(next(ps))
        if ps.nt.kind == Tokens.LPAREN
            @catcherror ps nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
            nextarg = EXPR{Quote}(Any[op2, nextarg])
        else
            @catcherror ps nextarg = @precedence ps DotOp - LtoR(DotOp) parse_unary(ps, op2)
        end
    elseif ps.nt.kind == Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        op2 = OPERATOR(next(ps))
        @catcherror ps nextarg = parse_call(ps, op2)
    else
        @catcherror ps nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
    end

    # Construction
    # NEEDS FIX
    if nextarg isa IDENTIFIER || nextarg isa EXPR{Vect} || (nextarg isa UnarySyntaxOpCall && is_exor(nextarg.arg1))
        ret = BinarySyntaxOpCall(ret, op, Quotenode(nextarg))
    elseif nextarg isa EXPR{MacroCall}
        mname = BinarySyntaxOpCall(ret, op, Quotenode(nextarg.args[1]))
        ret = EXPR{MacroCall}(Any[mname])
        for i = 2:length(nextarg.args)
            push!(ret, nextarg.args[i])
        end
    else
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    end
    return ret
end


function parse_operator_dddot(ps::ParseState, ret, op)
    return UnarySyntaxOpCall(ret, op)
end

function parse_operator_prime(ps::ParseState, ret, op)
    return UnarySyntaxOpCall(ret, op)
end

function parse_operator_anon_func(ps::ParseState, ret, op)
    @catcherror ps arg = @closer ps comma @precedence ps 0 parse_expression(ps)
    return BinarySyntaxOpCall(ret, op, EXPR{Block}(Any[arg]))
end

function parse_operator(ps::ParseState, ret, op)
    K,dot = op.kind, op.dot
    P = precedence(K)

    if ret isa EXPR{ChainOpCall} && (is_star(op) || is_plus(op)) && op.kind == ret.args[2].kind
        @catcherror ps nextarg = @precedence ps P - LtoR(P) parse_expression(ps)
        push!(ret, op)
        push!(ret, nextarg)
        return ret
    elseif ret isa BinaryOpCall && (is_star(op) || is_plus(op)) && op.kind == ret.op.kind && !ret.op.dot
        @catcherror ps nextarg = @precedence ps P - LtoR(P) parse_expression(ps)
        return EXPR{ChainOpCall}(Any[ret.arg1, ret.op, ret.arg2, op, nextarg])
    end

    if is_eq(op)
        return parse_operator_eq(ps, ret, op)
    elseif is_cond(op)
        return parse_operator_cond(ps, ret, op)
    elseif is_colon(op)
        return parse_operator_colon(ps, ret, op)
    elseif is_where(op)
        return parse_operator_where(ps, ret, op)
    elseif is_anon_func(op)
        return parse_operator_anon_func(ps, ret, op)
    elseif is_dot(op)
        return parse_operator_dot(ps, ret, op)
    elseif is_dddot(op)
        return parse_operator_dddot(ps, ret, op)
    elseif is_prime(op)
        return parse_operator_prime(ps, ret, op)
    elseif P == ComparisonOp
        return parse_comp_operator(ps, ret, op)
    elseif P == PowerOp
        return parse_operator_power(ps, ret, op)
    end
    @catcherror ps nextarg = @precedence ps P - LtoR(P) parse_expression(ps)

    # Construction
    if issyntaxcall(op)
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    else
        ret = BinaryOpCall(ret, op, nextarg)
    end
    return ret
end
