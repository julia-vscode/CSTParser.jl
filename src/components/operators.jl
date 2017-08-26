
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

precedence(op::Token) = op.kind == Tokens.DDDOT ? DddotOp :
                        op.kind < Tokens.begin_assignments ? 0 :
                        op.kind < Tokens.end_assignments ?   1 :
                       op.kind < Tokens.end_conditional ?    2 :
                       op.kind < Tokens.end_arrow ?          3 :
                       op.kind < Tokens.end_lazyor ?         4 :
                       op.kind < Tokens.end_lazyand ?        5 :
                       op.kind < Tokens.end_comparison ?     6 :
                       op.kind < Tokens.end_pipe ?           7 :
                       op.kind < Tokens.end_colon ?          8 :
                       op.kind < Tokens.end_plus ?           9 :
                       op.kind < Tokens.end_bitshifts ?      10 :
                       op.kind < Tokens.end_times ?          11 :
                       op.kind < Tokens.end_rational ?       12 :
                       op.kind < Tokens.end_power ?          13 :
                       op.kind < Tokens.end_decl ?           14 :
                       op.kind < Tokens.end_where ?          15 :
                       op.kind < Tokens.end_dot ?            16 :
                       op.kind == Tokens.ANON_FUNC ? AnonFuncOp :
                       op.kind == Tokens.PRIME ?             16 : 20

precedence(x) = 0
precedence(x::OPERATOR{P,K,dot}) where {P,K,dot} = Int(P)


isoperator(kind) = Tokens.begin_ops < kind < Tokens.end_ops
isoperator(t::Token) = isoperator(t.kind)


isunaryop(op::OPERATOR{P,K,D}) where {P,K,D} = isunaryop(K)
isunaryop(t::Token) = isunaryop(t.kind)

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


isunaryandbinaryop(t::Token) = isunaryandbinaryop(t.kind)
isunaryandbinaryop(kind) = kind == Tokens.PLUS ||
                           kind == Tokens.MINUS ||
                           kind == Tokens.EX_OR ||
                           kind == Tokens.ISSUBTYPE ||
                           kind == Tokens.ISSUPERTYPE ||
                           kind == Tokens.AND ||
                           kind == Tokens.APPROX ||
                           kind == Tokens.DECLARATION ||
                           kind == Tokens.COLON

isbinaryop(op::OPERATOR{P,K,D}) where {P,K,D} = isbinaryop(K)
isbinaryop(t::Token) = isbinaryop(t.kind)
isbinaryop(kind) = isoperator(kind) &&
                    !(kind == Tokens.SQUARE_ROOT ||
                    kind == Tokens.CUBE_ROOT ||
                    kind == Tokens.QUAD_ROOT ||
                    kind == Tokens.NOT ||
                    kind == Tokens.NOT_SIGN)

isassignment(t::Token) = Tokens.begin_assignments < t.kind < Tokens.end_assignments

function non_dotted_op(t::Token)
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
function issyntaxcall(op::OPERATOR{P,K,dot}) where {P,K,dot}
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
function issyntaxunarycall(op::OPERATOR{P,K,false}) where {P,K}
    K == Tokens.EX_OR ||
    K == Tokens.AND ||
    K == Tokens.DECLARATION ||
    K == Tokens.ISSUBTYPE ||
    K == Tokens.ISSUPERTYPE
end



LtoR(prec::Int) = AssignmentOp ≤ prec ≤ LazyAndOp || prec == PowerOp


"""
    parse_unary(ps)

Having hit a unary operator at the start of an expression return a call.
"""
function parse_unary(ps::ParseState, op::OPERATOR{P,K,dot}) where {P,K,dot}
    if (op isa OPERATOR{PlusOp,Tokens.PLUS,false} || op isa OPERATOR{PlusOp,Tokens.MINUS,false}) && (ps.nt.kind ==  Tokens.INTEGER || ps.nt.kind == Tokens.FLOAT) && isemptyws(ps.ws)
        next(ps)
        arg = INSTANCE(ps)
        return LITERAL{ps.t.kind}(op.fullspan + arg.fullspan, first(arg.span):(last(arg.span) + length(op.span)), string(ps.lt.val, ps.t.val))
        return arg
    end

    # Parsing
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

function parse_unary(ps::ParseState, op::OPERATOR{ColonOp,Tokens.COLON,false})
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
function parse_operator(ps::ParseState, ret, op::OPERATOR{AssignmentOp,Tokens.EQ,false})
    # Parsing
    @catcherror ps nextarg = @precedence ps AssignmentOp - LtoR(AssignmentOp) parse_expression(ps)

    if is_func_call(ret)
        # Construction
        # NOTE: prior to v"0.6.0-dev.2360" (PR #20076), there was an issue w/ scheme parser
        if VERSION > v"0.6.0-dev.2360" || (!(ret isa BinarySyntaxOpCall{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}} && (ret <: Union{UnaryOpCall,UnarySyntaxOpCall,BinaryOpCall,BinarySyntaxOpCall} || length(ret.args) > 1)) && ps.closer.precedence != 0)
            nextarg = EXPR{Block}(Any[nextarg])
        end
    end
    
    return BinarySyntaxOpCall(ret, op, nextarg)
end

# Parse conditionals
function parse_operator(ps::ParseState, ret, op::OPERATOR{ConditionalOp,Tokens.CONDITIONAL,false})
    # Parsing
    @catcherror ps nextarg = @closer ps ifop parse_expression(ps)
    @catcherror ps op2 = INSTANCE(next(ps))
    @catcherror ps nextarg2 = @closer ps comma @precedence ps 0 parse_expression(ps)

    # Construction
    ret = ConditionalOpCall(ret, op, nextarg, op2, nextarg2)
    return ret
end

# Parse comparisons
function parse_operator(ps::ParseState, ret, op::OPERATOR{ComparisonOp})
    # Parsing
    @catcherror ps nextarg = @precedence ps ComparisonOp - LtoR(ComparisonOp) parse_expression(ps)

    # Construction
    if ret isa EXPR{Comparison}
        push!(ret, op)
        push!(ret, nextarg)
    elseif ret isa BinaryOpCall && precedence(ret.op) == ComparisonOp
        ret = EXPR{Comparison}(Any[ret.arg1, ret.op, ret.arg2, op, nextarg])
    elseif ret isa BinarySyntaxOpCall && (ret.op isa OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false} || ret.op isa OPERATOR{ComparisonOp,Tokens.ISSUPERTYPE,false})
        ret = EXPR{Comparison}(Any[ret.arg1, ret.op, ret.arg2, op, nextarg])
    elseif (op isa OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false} || op isa OPERATOR{ComparisonOp,Tokens.ISSUPERTYPE,false})
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    else
        ret = BinaryOpCall(ret, op, nextarg)
    end
    return ret
end

# Parse ranges
function parse_operator(ps::ParseState, ret, op::OPERATOR{ColonOp,Tokens.COLON,false})
    # Parsing
    @catcherror ps nextarg = @precedence ps ColonOp - LtoR(ColonOp) parse_expression(ps)

    # Construction
    if ret isa BinarySyntaxOpCall{OPERATOR{ColonOp,Tokens.COLON,false}} 
        ret = EXPR{ColonOpCall}([ret.arg1, ret.op, ret.arg2])
        push!(ret, op)
        push!(ret, nextarg)
    else
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    end
    return ret
end

parse_operator(ps::ParseState, ret::BinaryOpCall, op::OPERATOR{PlusOp,Tokens.PLUS,false}) = parse_chain_operator(ps, ret, op)
parse_operator(ps::ParseState, ret::EXPR{ChainOpCall}, op::OPERATOR{PlusOp,Tokens.PLUS,false}) = parse_chain_operator(ps, ret, op)

parse_operator(ps::ParseState, ret::BinaryOpCall, op::OPERATOR{TimesOp,Tokens.STAR,false}) = parse_chain_operator(ps, ret, op)
parse_operator(ps::ParseState, ret::EXPR{ChainOpCall}, op::OPERATOR{TimesOp,Tokens.STAR,false}) = parse_chain_operator(ps, ret, op)


function parse_chain_operator(ps::ParseState, ret::EXPR{ChainOpCall}, op::OPERATOR{P,K,false}) where {P,K}
    if ret.args[2] isa OPERATOR{P,K,false}
        # Parsing
        @catcherror ps nextarg = @precedence ps P - LtoR(P) parse_expression(ps)

        # Construction
        push!(ret, op)
        push!(ret, nextarg)
    else
        ret = invoke(parse_operator, Tuple{ParseState,EXPR,OPERATOR{P1,K1,dot} where {P1,K1,dot}}, ps, ret, op)
    end
    return ret
end

function parse_chain_operator(ps::ParseState, ret::BinaryOpCall, op::OPERATOR{P,K,false}) where {P,K}
    if ret.op isa OPERATOR{P,K,false} && span(ret.op) > 0
        @catcherror ps nextarg = @precedence ps P - LtoR(P) parse_expression(ps)
        ret = EXPR{ChainOpCall}([ret.arg1, ret.op, ret.arg2, op, nextarg])
    else
        ret = invoke(parse_operator, Tuple{ParseState,BinaryOpCall,OPERATOR{P,K,dot} where {P1,K1,dot}}, ps, ret, op)
    end
    return ret
end


# Parse power (special case for preceding unary ops)
function parse_operator(ps::ParseState, ret, op::OPERATOR{PowerOp})
    # Parsing
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
function parse_operator(ps::ParseState, ret, op::OPERATOR{WhereOp,Tokens.WHERE,false})
    args = Any[]
    if ps.nt.kind == Tokens.LBRACE
        next(ps)
        push!(args, INSTANCE(ps))
        @nocloser ps inwhere while ps.nt.kind != Tokens.RBRACE
            @catcherror ps a = @default ps @nocloser ps newline @closer ps comma @closer ps brace parse_expression(ps)
            push!(args, a)
            if ps.nt.kind == Tokens.COMMA
                next(ps)
                push!(args, INSTANCE(ps))
            end
        end
        next(ps)
        push!(args, INSTANCE(ps))
    else
        @catcherror ps nextarg = @precedence ps 5 @closer ps inwhere parse_expression(ps)
        push!(args, nextarg)
    end

    # Construction
    return WhereOpCall(ret, op, args)
end

# parse dot access
function parse_operator(ps::ParseState, ret, op::OPERATOR{DotOp,Tokens.DOT,false})
    # Parsing
    if ps.nt.kind == Tokens.LPAREN
        @catcherror ps sig = @default ps @closer ps paren parse_call(ps, ret)
        args = EXPR{TupleH}(sig.args[2:end])
        ret = BinarySyntaxOpCall(ret, op, args)
        return ret
    elseif iskw(ps.nt) || ps.nt.kind == Tokens.IN || ps.nt.kind == Tokens.ISA || ps.nt.kind == Tokens.WHERE
        next(ps)
        nextarg = IDENTIFIER(ps)
    elseif ps.nt.kind == Tokens.COLON
        next(ps)
        op2 = INSTANCE(ps)
        if ps.nt.kind == Tokens.LPAREN
            @catcherror ps nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
            nextarg = EXPR{Quote}(Any[op2, nextarg])
        else
            @catcherror ps nextarg = @precedence ps DotOp - LtoR(DotOp) parse_unary(ps, op2)
        end
    elseif ps.nt.kind == Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        next(ps)
        op2 = OPERATOR(ps)
        @catcherror ps nextarg = parse_call(ps, op2)
    else
        @catcherror ps nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
    end

    # Construction
    # NEEDS FIX
    if nextarg isa IDENTIFIER || nextarg isa EXPR{Vect} || nextarg isa UnarySyntaxOpCall && nextarg.arg1 isa OPERATOR{PlusOp,Tokens.EX_OR,false}
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


function parse_operator(ps::ParseState, ret, op::OPERATOR{DddotOp,Tokens.DDDOT,false})
    return UnarySyntaxOpCall(ret, op)
end

function parse_operator(ps::ParseState, ret, op::OPERATOR{16,Tokens.PRIME,dot}) where dot
    return UnarySyntaxOpCall(ret, op)
end

function parse_operator(ps::ParseState, ret, op::OPERATOR{AnonFuncOp,Tokens.ANON_FUNC,false})
    # Parsing
    @catcherror ps arg = @closer ps comma @precedence ps 0 parse_expression(ps)

    # Construction

    ret = BinarySyntaxOpCall(ret, op, EXPR{Block}(Any[arg]))

    return ret
end

function parse_operator(ps::ParseState, ret, op::OPERATOR{P,K,dot}) where {P,K,dot}
    # Parsing
    @catcherror ps nextarg = @precedence ps P - LtoR(P) parse_expression(ps)

    # Construction
    if issyntaxcall(op)
        ret = BinarySyntaxOpCall(ret, op, nextarg)
    else
        ret = BinaryOpCall(ret, op, nextarg)
    end
    return ret
end
