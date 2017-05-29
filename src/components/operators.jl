# Operator hierarchy
const AssignmentOp  = 1
const ConditionalOp = 2
const ArrowOp       = 3
const LazyOrOp      = 4
const LazyAndOp     = 5
const ComparisonOp  = 6
const PipeOp        = 7
const ColonOp       = 8
const PlusOp        = 9
const BitShiftOp    = 10
const TimesOp       = 11
const RationalOp    = 12
const PowerOp       = 13
const DeclarationOp = 14
const WhereOp       = 15
const DotOp         = 16
const PrimeOp       = 16
const DddotOp       = 7
const AnonFuncOp    = 14


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
                       op < Tfokens.end_rational ?   12 :
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
precedence(x::EXPR{OPERATOR{P,K,dot}}) where {P, K, dot} = P


isoperator(kind) = Tokens.begin_ops < kind < Tokens.end_ops
isoperator(t::Token) = isoperator(t.kind)


isunaryop(op::EXPR{OPERATOR{P,K,D}}) where {P, K, D} = isunaryop(K)
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

isbinaryop(op::EXPR{OPERATOR{P,K,D}}) where {P, K, D} = isbinaryop(K)
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
function issyntaxcall(op::EXPR{OPERATOR{P,K,dot}}) where {P, K, dot}
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
function issyntaxunarycall(op::EXPR{OPERATOR{P,K,false}}) where {P, K}
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
function parse_unary(ps::ParseState, op::EXPR{OPERATOR{P,K,dot}}) where {P, K, dot}
    startbyte = ps.nt.startbyte - op.span
    if (op isa EXPR{OPERATOR{PlusOp,Tokens.PLUS,false}} || op isa EXPR{OPERATOR{PlusOp,Tokens.MINUS,false}}) && (ps.nt.kind ==  Tokens.INTEGER || ps.nt.kind == Tokens.FLOAT) && isemptyws(ps.ws)
        next(ps)
        arg = INSTANCE(ps)
        arg.span += op.span
        if op isa EXPR{OPERATOR{PlusOp,Tokens.MINUS,false}}
            arg.val = string("-", arg.val)
        end
        return arg
    end

    # Parsing
    prec = P == DeclarationOp ? DeclarationOp : 
                K == Tokens.AND ? 14 : 
                K == Tokens.EX_OR ? 20 : 13
    @catcherror ps startbyte arg = @precedence ps prec parse_expression(ps)
    
    if issyntaxunarycall(op)
        ret = EXPR{UnarySyntaxOpCall}(EXPR[op, arg], op.span + arg.span, Variable[], "")
    else
        ret = EXPR{Call}(EXPR[op, arg], op.span + arg.span, Variable[], "")
    end
    return ret
end

function parse_unary(ps::ParseState, op::EXPR{OPERATOR{ColonOp,Tokens.COLON,false}})
    startbyte = ps.nt.startbyte - op.span
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords || 
        Tokens.begin_literal < ps.nt.kind < Tokens.end_literal || 
        isoperator(ps.nt.kind) ||
        ps.nt.kind == Tokens.IDENTIFIER
        # Parsing
        next(ps)
        arg = INSTANCE(ps)
        return EXPR{Quotenode}(EXPR[op, arg], op.span + arg.span, Variable[], "")
    elseif closer(ps)
        return op
    else
        # Parsing
        @catcherror ps startbyte arg = @precedence ps 20 parse_expression(ps)
        return EXPR{Quote}(EXPR[op, arg], op.span + arg.span, Variable[], "")
    end
end

# Parse assignments
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}})
    startbyte = ps.nt.startbyte - op.span - ret.span
    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps AssignmentOp - LtoR(AssignmentOp) parse_expression(ps)
    
    if is_func_call(ret)
        # Construction
        # NOTE : issue w/ scheme parser
        if length(ret.args) > 1 && !(ret.args[2] isa EXPR{OPERATOR{DeclarationOp,Tokens.DECLARATION,false}}) && ps.closer.precedence != 0
            nextarg = EXPR{Block}(EXPR[nextarg], nextarg.span, Variable[], "")
        end
        # Linting
        @scope ps Scope{Tokens.FUNCTION} _lint_func_sig(ps, ret, startbyte + (0:ret.span))

        ret1 = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
        ret1.defs = [Variable(function_name(ret), :Function, ret1)]
        return ret1
    else
        defs = ps.trackscope ? _track_assignment(ps, ret, nextarg) : Variable[]
        if nextarg isa EXPR{BinarySyntaxOpCall} && nextarg.args[2] isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
            append!(defs, nextarg.defs)
            empty!(nextarg.defs)
        end
        ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
        ret.defs = defs
        return ret
    end
end

# Parse conditionals
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{ConditionalOp,Tokens.CONDITIONAL,false}})
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    @catcherror ps startbyte nextarg = @closer ps ifop parse_expression(ps)
    @catcherror ps startbyte op2 = INSTANCE(next(ps))
    @catcherror ps startbyte nextarg2 = @closer ps comma @precedence ps 0 parse_expression(ps)

    # Construction
    ret = EXPR{ConditionalOpCall}(EXPR[ret, op, nextarg, op2, nextarg2], ps.nt.startbyte - startbyte, Variable[], "")
    return ret
end

# Parse comparisons
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{ComparisonOp,K,dot}}) where {K, dot}
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps ComparisonOp - LtoR(ComparisonOp) parse_expression(ps)

    # Construction
    if ret isa EXPR{Comparison}
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.span += op.span + nextarg.span
    elseif ret isa EXPR{BinaryOpCall} && precedence(ret.args[2]) == ComparisonOp
        ret = EXPR{Comparison}(EXPR[ret.args[1], ret.args[2], ret.args[3], op, nextarg], ret.span + op.span + nextarg.span, Variable[], "")
    elseif ret isa EXPR{BinarySyntaxOpCall} && (ret.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}} || ret.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUPERTYPE,false}})
        ret = EXPR{Comparison}(EXPR[ret.args[1], ret.args[2], ret.args[3], op, nextarg], ret.span + op.span + nextarg.span, Variable[], "")
    elseif (op isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUBTYPE,false}} || op isa EXPR{OPERATOR{ComparisonOp,Tokens.ISSUPERTYPE,false}})
        ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, nextarg], ret.span + op.span + nextarg.span, Variable[], "")
    else
        ret = EXPR{BinaryOpCall}(EXPR[ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
    end
    return ret
end

# Parse ranges
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{ColonOp,Tokens.COLON,false}})
    startbyte = ps.t.startbyte

    # Parsing
    @catcherror ps startbyte - op.span - ret.span nextarg = @precedence ps ColonOp - LtoR(ColonOp) parse_expression(ps)

    # Construction
    if ret isa EXPR{BinarySyntaxOpCall} && ret.args[2] isa EXPR{OPERATOR{ColonOp,Tokens.COLON,false}} && length(ret.args) == 3
        ret = EXPR{ColonOpCall}(ret.args, ret.span, Variable[], "")
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.span += ps.nt.startbyte - startbyte
    else
        ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, nextarg], ret.span + ps.nt.startbyte - startbyte, Variable[], "")
    end
    return ret
end

parse_operator(ps::ParseState, ret::EXPR{BinaryOpCall}, op::EXPR{OPERATOR{PlusOp,Tokens.PLUS,false}}) = parse_chain_operator(ps, ret, op)
parse_operator(ps::ParseState, ret::EXPR{ChainOpCall}, op::EXPR{OPERATOR{PlusOp,Tokens.PLUS,false}}) = parse_chain_operator(ps, ret, op)

parse_operator(ps::ParseState, ret::EXPR{BinaryOpCall}, op::EXPR{OPERATOR{TimesOp,Tokens.STAR,false}}) = parse_chain_operator(ps, ret, op)
parse_operator(ps::ParseState, ret::EXPR{ChainOpCall}, op::EXPR{OPERATOR{TimesOp,Tokens.STAR,false}}) = parse_chain_operator(ps, ret, op)


function parse_chain_operator(ps::ParseState, ret::EXPR{ChainOpCall}, op::EXPR{OPERATOR{P,K,false}}) where {P, K}
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    if ret.args[2] isa EXPR{OPERATOR{P,K,false}}
        # Parsing
        @catcherror ps startbyte nextarg = @precedence ps P - LtoR(P) parse_expression(ps)

        # Construction
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
    else
        ret = invoke(parse_operator, Tuple{ParseState,EXPR,EXPR{OPERATOR{P1,K1,dot}} where {P1, K1, dot}}, ps, ret, op)
    end
    return ret
end

function parse_chain_operator(ps::ParseState, ret::EXPR{BinaryOpCall}, op::EXPR{OPERATOR{P,K,false}}) where {P, K}
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    if ret.args[2] isa EXPR{OPERATOR{P,K,false}} && ret.args[2].span > 0
        @catcherror ps startbyte nextarg = @precedence ps P - LtoR(P) parse_expression(ps)
        ret = EXPR{ChainOpCall}(ret.args, ret.span, Variable[], "")
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
    else
        ret = invoke(parse_operator, Tuple{ParseState,EXPR,EXPR{OPERATOR{P,K,dot}} where {P1, K1, dot}}, ps, ret, op)
    end
    return ret
end


# Parse power (special case for preceding unary ops)
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{PowerOp,K,dot}}) where {K, dot}
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps PowerOp - LtoR(PowerOp) @closer ps inwhere parse_expression(ps)

    # Construction
    # NEEDS FIX
    if ret isa EXPR{UnaryOpCall} 
        if false
            xx = EXPR{InvisBrackets}([ret], ret.span, Variable[], "")
            nextarg = EXPR{BinaryOpCall}(EXPR[op, xx, nextarg], op.span + xx.span + nextarg.span, Variable[], "") 
        else
            nextarg = EXPR{BinaryOpCall}(EXPR[ret.args[2], op, nextarg], op.span + ret.args[2].span + nextarg.span, Variable[], "")
        end
        ret = EXPR{UnaryOpCall}(EXPR[ret.args[1], nextarg], ret.args[1].span + nextarg.span, Variable[], "")
    else
        ret = EXPR{BinaryOpCall}(EXPR[ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
    end
    return ret
end


# parse where
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{WhereOp,Tokens.WHERE,false}})
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    # Parsing
    ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op], 0, Variable[], "")
    # Parsing
    if ps.nt.kind == Tokens.LBRACE
        next(ps)
        push!(ret.args, INSTANCE(ps))
        while ps.nt.kind != Tokens.RBRACE
            @catcherror ps startbyte a = @default ps @nocloser ps newline @closer ps comma @closer ps brace parse_expression(ps)
            push!(ret.args, a)
            if ps.nt.kind == Tokens.COMMA
                next(ps)
                push!(ret.args, INSTANCE(ps))
                format_comma(ps)
            end
        end
        next(ps)
        push!(ret.args, INSTANCE(ps))
    else
        @catcherror ps startbyte nextarg = @precedence ps 5 @closer ps inwhere parse_expression(ps)
        push!(ret.args, nextarg)
    end
    
    # Construction
    ret.span = ps.nt.startbyte - startbyte
    return ret
end

# parse dot access
function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{DotOp,Tokens.DOT,false}})
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    if ps.nt.kind == Tokens.LPAREN
        startbyte1 = ps.nt.startbyte
        @catcherror ps startbyte sig = @default ps @closer ps paren parse_call(ps, ret)
        args = EXPR{TupleH}(sig.args[2:end], ps.nt.startbyte - startbyte1, Variable[], "")
        ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, args], ps.nt.startbyte - startbyte, Variable[], "")
        return ret
    elseif iskw(ps.nt) || ps.nt.kind == Tokens.IN || ps.nt.kind == Tokens.ISA || ps.nt.kind == Tokens.WHERE
        next(ps)
        # nextarg = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, Symbol(lowercase(string(ps.t.kind))))
        nextarg = EXPR{IDENTIFIER}(EXPR[], ps.nt.startbyte - ps.t.startbyte, Variable[], lowercase(string(ps.t.kind)))
    elseif ps.nt.kind == Tokens.COLON
        next(ps)
        op2 = INSTANCE(ps)
        if ps.nt.kind == Tokens.LPAREN
            @catcherror ps startbyte nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
            nextarg = EXPR{Quote}(EXPR[op2, nextarg], op2.span + nextarg.span, Variable[], "")
        else
            @catcherror ps startbyte nextarg = @precedence ps DotOp - LtoR(DotOp) parse_unary(ps, op2)
        end
    elseif ps.nt.kind == Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        next(ps)
        op2 = OPERATOR(ps)
        @catcherror ps startbyte nextarg = parse_call(ps, op2)
    else
        @catcherror ps startbyte nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
    end

    # Construction
    # NEEDS FIX
    if nextarg isa EXPR{IDENTIFIER} || nextarg isa EXPR{Vect} || nextarg isa EXPR{UnarySyntaxOpCall} && nextarg.args[1] isa EXPR{OPERATOR{PlusOp,Tokens.EX_OR,false}}
        ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, Quotenode(nextarg)], op.span + ret.span + nextarg.span, Variable[], "")
    elseif nextarg isa EXPR{MacroCall}
        mname = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, Quotenode(nextarg.args[1])], ret.span + op.span + nextarg.args[1].span, Variable[], "")
        ret = EXPR{MacroCall}(EXPR[mname], ret.span + op.span + nextarg.span, Variable[], "")
        for i = 2:length(nextarg.args)
            push!(ret.args, nextarg.args[i])
        end
    else
        ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
    end
    return ret
end


function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{DddotOp,Tokens.DDDOT,false}})
    return EXPR{UnarySyntaxOpCall}(EXPR[ret, op], op.span + ret.span, Variable[], "")
end

function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{16,Tokens.PRIME,dot}}) where dot
    return EXPR{UnarySyntaxOpCall}(EXPR[ret, op], op.span + ret.span, Variable[], "")
end

function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{P,Tokens.ANON_FUNC,false}}) where {P}
    startbyte = ps.nt.startbyte - op.span - ret.span
    # Parsing
    @catcherror ps startbyte arg = @closer ps comma @precedence ps 0 parse_expression(ps)

    # Construction
    if ret isa EXPR{TupleH}
        for a in ret.args
            if !(a isa EXPR{P1} where P1 <: PUNCTUATION)
                push!(ret.defs, Variable(Expr(a), get_t(a), a))
            end
        end
    else
        push!(ret.defs, Variable(Expr(ret), get_t(ret), ret))
    end
    ret = EXPR{BinarySyntaxOpCall}(EXPR[ret, op, EXPR{Block}(EXPR[arg], arg.span, Variable[], "")], ps.nt.startbyte - startbyte, Variable[], "")
    
    return ret
end

function parse_operator(ps::ParseState, ret::EXPR, op::EXPR{OPERATOR{P,K,dot}}) where {P, K, dot}
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps P - LtoR(P) parse_expression(ps)
    
    # Construction
    if issyntaxcall(op)
        ret = EXPR{BinarySyntaxOpCall}([ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
    else
        ret = EXPR{BinaryOpCall}([ret, op, nextarg], op.span + ret.span + nextarg.span, Variable[], "")
    end
    return ret
end


