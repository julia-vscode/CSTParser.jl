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

precedence(op::Token) = op.kind < Tokens.begin_assignments ? 0 :
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
                       op.kind == Tokens.PRIME ?             16 : 20

precedence(x) = 0

isoperator(kind) = Tokens.begin_ops < kind < Tokens.end_ops
isoperator(t::Token) = isoperator(t.kind)


isunaryop{P, K, D}(op::OPERATOR{P, K, D}) = isunaryop(K)
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

isbinaryop{P, K, D}(op::OPERATOR{P, K, D}) = isbinaryop(K)
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
function issyntaxcall{P, K}(op::OPERATOR{P, K})
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
function issyntaxunarycall{P, K}(op::OPERATOR{P, K})
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
function parse_unary{P, K}(ps::ParseState, op::OPERATOR{P, K})
    startbyte = ps.nt.startbyte - op.span
    if (op isa OPERATOR{PlusOp, Tokens.PLUS} || op isa OPERATOR{PlusOp, Tokens.MINUS}) && (ps.nt.kind ==  Tokens.INTEGER || ps.nt.kind == Tokens.FLOAT) && isempty(ps.ws)
        next(ps)
        arg = INSTANCE(ps)
        arg.span += op.span
        if op isa OPERATOR{PlusOp, Tokens.MINUS}
            arg.val = string("-", arg.val)
        end
        return arg
    end

    # Parsing
    prec = P == DeclarationOp ? DeclarationOp : 
                K == Tokens.EX_OR ? 20 : 13
    @catcherror ps startbyte arg = @precedence ps prec parse_expression(ps)
    
    if issyntaxunarycall(op)
        ret = EXPR(op, SyntaxNode[arg], op.span + arg.span)
    else
        ret = EXPR(CALL, SyntaxNode[op, arg], op.span + arg.span)
    end
    return ret
end

function parse_unary(ps::ParseState, op::OPERATOR{ColonOp, Tokens.COLON})
    startbyte = ps.nt.startbyte - op.span
    if Tokens.begin_keywords < ps.nt.kind < Tokens.end_keywords || 
        Tokens.begin_literal < ps.nt.kind < Tokens.end_literal || 
        isoperator(ps.nt.kind) ||
        ps.nt.kind == Tokens.IDENTIFIER
        # Parsing
        next(ps)
        arg = INSTANCE(ps)
        return QUOTENODE(arg, op.span + arg.span, [op])
    elseif closer(ps)
        return op
    else
        # Parsing
        @catcherror ps startbyte arg = @precedence ps 20 parse_expression(ps)
        return EXPR(QUOTE, [arg], op.span + arg.span, [op])
    end
end

# function parse_unary(ps::ParseState, op::OPERATOR{PlusOp, Tokens.EX_OR, false})
#     startbyte = ps.nt.startbyte - op.span
#     # Parsing
#     @catcherror ps startbyte arg = @precedence ps 20 parse_expression(ps)
#     # Construction
#     ret = EXPR(op, [arg], op.span + arg.span)
#     return ret
# end


# Parse assignments
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{AssignmentOp, Tokens.EQ})
    startbyte = ps.nt.startbyte - op.span - ret.span
    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps AssignmentOp - LtoR(AssignmentOp) parse_expression(ps)
    
    if is_func_call(ret)
        # Construction
        # NOTE : issue w/ scheme parser
        if !(ret.head isa OPERATOR{DeclarationOp, Tokens.DECLARATION})
            nextarg = EXPR(BLOCK, SyntaxNode[nextarg], nextarg.span)
        end
        # Linting
        @scope ps Scope{Tokens.FUNCTION} _lint_func_sig(ps, ret)
        
        ret1 = EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
        ret1.defs = [Variable(function_name(ret), :Function, ret1)]
        return ret1
    else
        defs = ps.trackscope ? _track_assignment(ps, ret, nextarg) : Variable[]
        ret = EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
        ret.defs = defs
        return ret
    end
end

# Parse conditionals
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{ConditionalOp})
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    @catcherror ps startbyte nextarg = @closer ps ifop parse_expression(ps)
    @catcherror ps startbyte op2 = INSTANCE(next(ps))
    @catcherror ps startbyte nextarg2 = @closer ps comma @precedence ps 0 parse_expression(ps)

    # Construction
    ret = EXPR(IF, SyntaxNode[ret, nextarg, nextarg2], ps.nt.startbyte - startbyte, INSTANCE[op, op2])
    return ret
end

# Parse comparisons
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{ComparisonOp})
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps ComparisonOp - LtoR(ComparisonOp) parse_expression(ps)

    # Construction
    if ret isa EXPR && ret.head == COMPARISON
        push!(ret.args, op)
        push!(ret.args, nextarg)
        ret.span += op.span + nextarg.span
    elseif ret isa EXPR && (ret.head == CALL && ret.args[1] isa OPERATOR{ComparisonOp} && isempty(ret.punctuation))
        ret = EXPR(COMPARISON, SyntaxNode[ret.args[2], ret.args[1], ret.args[3], op, nextarg], ret.args[2].span + ret.args[1].span + ret.args[3].span + op.span + nextarg.span)
    elseif ret isa EXPR && (ret.head isa OPERATOR{ComparisonOp, Tokens.ISSUBTYPE} || ret.head isa OPERATOR{ComparisonOp, Tokens.ISSUPERTYPE})
        ret = EXPR(COMPARISON, SyntaxNode[ret.args[1], ret.head, ret.args[2], op, nextarg], ret.span + op.span + nextarg.span)
    elseif (op isa OPERATOR{ComparisonOp, Tokens.ISSUBTYPE} || op isa OPERATOR{ComparisonOp, Tokens.ISSUPERTYPE})
        ret = EXPR(op, SyntaxNode[ret, nextarg], ret.span + op.span + nextarg.span)
    else
        ret = EXPR(CALL, SyntaxNode[op, ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end

# Parse ranges
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{ColonOp, Tokens.COLON})
    startbyte = ps.t.startbyte

    # Parsing
    @catcherror ps startbyte - op.span - ret.span nextarg = @precedence ps ColonOp - LtoR(ColonOp) parse_expression(ps)

    # Construction
    if ret isa EXPR && ret.head isa OPERATOR{ColonOp, Tokens.COLON} && length(ret.args) == 2
        push!(ret.punctuation, op)
        push!(ret.args, nextarg)
        ret.span += ps.nt.startbyte - startbyte
    else
        ret = EXPR(op, SyntaxNode[ret, nextarg], ret.span + ps.nt.startbyte - startbyte)
    end
    return ret
end

parse_operator(ps::ParseState, ret::EXPR, op::OPERATOR{PlusOp, Tokens.PLUS, false}) = parse_chain_operator(ps, ret, op)

function parse_operator(ps::ParseState, ret::EXPR, op::OPERATOR{TimesOp, Tokens.STAR, false})  parse_chain_operator(ps, ret, op)

function parse_chain_operator{P, K}(ps::ParseState, ret::EXPR, op::OPERATOR{P, K, false})
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    if ret.head == CALL && ret.args[1] isa OPERATOR{P, K, false} && ret.args[1].span > 0
        # Parsing
        @catcherror ps startbyte nextarg = @precedence ps P - LtoR(P) parse_expression(ps)

        # Construction
        push!(ret.args, nextarg)
        ret.span += nextarg.span + op.span
        push!(ret.punctuation, op)
    else
        ret = invoke(parse_operator, Tuple{ParseState, SyntaxNode, OPERATOR}, ps, ret, op)
    end
    return ret
end


# Parse power (special case for preceding unary ops)
function parse_operator{K}(ps::ParseState, ret::SyntaxNode, op::OPERATOR{PowerOp, K})
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps PowerOp - LtoR(PowerOp) @closer ps inwhere parse_expression(ps)

    # Construction
    if ret isa EXPR && ret.head == CALL && ret.args[1] isa OPERATOR && isunaryop(ret.args[1])
        if !isempty(ret.punctuation)
            xx = EXPR(HEAD{InvisibleBrackets}(0), [ret.args[2]], ret.args[2].span + sum(p.span for p in ret.punctuation), ret.punctuation)
            nextarg = EXPR(CALL, [op, xx, nextarg], op.span + xx.span + nextarg.span) 
        else
            nextarg = EXPR(CALL, [op, ret.args[2], nextarg], op.span + ret.args[2].span + nextarg.span)
        end
        ret = EXPR(CALL, [ret.args[1], nextarg], ret.args[1].span + nextarg.span)
    else
        ret = EXPR(CALL, SyntaxNode[op, ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end


# parse where
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{WhereOp, Tokens.WHERE})
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    # Parsing
    ret = EXPR(op, SyntaxNode[ret], 0)
    # Parsing
    if ps.nt.kind == Tokens.LBRACE
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
        while ps.nt.kind != Tokens.RBRACE
            @catcherror ps startbyte a = @default ps @nocloser ps newline @closer ps comma @closer ps brace parse_expression(ps)
            push!(ret.args, a)
            if ps.nt.kind == Tokens.COMMA
                next(ps)
                push!(ret.punctuation, INSTANCE(ps))
                format_comma(ps)
            end
        end
        next(ps)
        push!(ret.punctuation, INSTANCE(ps))
    else
        @catcherror ps startbyte nextarg = @precedence ps 5 @closer ps inwhere parse_expression(ps)
        push!(ret.args, nextarg)
    end
    
    # Construction
    ret.span = ps.nt.startbyte - startbyte
    return ret
end

# parse dot access
function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{DotOp})
    startbyte = ps.nt.startbyte - op.span - ret.span

    # Parsing
    if ps.nt.kind == Tokens.LPAREN
        startbyte1 = ps.nt.startbyte
        @catcherror ps startbyte sig = @default ps @closer ps paren parse_call(ps, ret)
        args = EXPR(TUPLE, sig.args[2:end], ps.nt.startbyte - startbyte1, sig.punctuation)
        ret = EXPR(op, [ret, args], ps.nt.startbyte - startbyte)
        return ret
    elseif iskw(ps.nt) || ps.nt.kind == Tokens.IN || ps.nt.kind == Tokens.ISA || ps.nt.kind == Tokens.WHERE
        next(ps)
        nextarg = IDENTIFIER(ps.nt.startbyte - ps.t.startbyte, Symbol(lowercase(string(ps.t.kind))))
    elseif ps.nt.kind == Tokens.COLON
        next(ps)
        op2 = INSTANCE(ps)
        if ps.nt.kind == Tokens.LPAREN
            @catcherror ps startbyte nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
            nextarg = EXPR(QUOTE, [nextarg], op2.span + nextarg.span, [op2])
        else
            @catcherror ps startbyte nextarg = @precedence ps DotOp - LtoR(DotOp) parse_unary(ps, op2)
        end
    elseif ps.nt.kind == Tokens.EX_OR && ps.nnt.kind == Tokens.LPAREN
        @catcherror ps startbyte nextarg = parse_expression(ps)
    else
        @catcherror ps startbyte nextarg = @precedence ps DotOp - LtoR(DotOp) parse_expression(ps)
    end

    # Construction
    if nextarg isa INSTANCE || (nextarg isa EXPR && nextarg.head == VECT) || nextarg isa EXPR && nextarg.head isa OPERATOR{PlusOp, Tokens.EX_OR}
        ret = EXPR(op, SyntaxNode[ret, QUOTENODE(nextarg)], op.span + ret.span + nextarg.span)
    elseif nextarg isa EXPR && nextarg.head == MACROCALL
        mname = EXPR(op, [ret, QUOTENODE(nextarg.args[1])], ret.span + op.span + nextarg.args[1].span)
        ret = EXPR(MACROCALL, [mname, nextarg.args[2:end]...], ret.span + op.span + nextarg.span, nextarg.punctuation)
    else
        ret = EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end


function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{0, Tokens.DDDOT})
    return EXPR(op, SyntaxNode[ret], op.span + ret.span)
end

function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{16, Tokens.PRIME})
    return EXPR(op, SyntaxNode[ret], op.span + ret.span)
end

function parse_operator(ps::ParseState, ret::SyntaxNode, op::OPERATOR{20, Tokens.ANON_FUNC})
    startbyte = ps.nt.startbyte - op.span - ret.span
    # Parsing
    @catcherror ps startbyte arg = @precedence ps 0 parse_expression(ps)

    # Construction
    ret = EXPR(op, [ret, EXPR(BLOCK, [arg], arg.span)], ps.nt.startbyte - startbyte)
    
    return ret
end

function parse_operator{P, K}(ps::ParseState, ret::SyntaxNode, op::OPERATOR{P, K})
    startbyte = ps.nt.startbyte - op.span - ret.span
    
    # Parsing
    @catcherror ps startbyte nextarg = @precedence ps P - LtoR(P) parse_expression(ps)
    
    # Construction
    if issyntaxcall(op)
        ret = EXPR(op, SyntaxNode[ret, nextarg], op.span + ret.span + nextarg.span)
    else
        ret = EXPR(CALL, SyntaxNode[op, ret, nextarg], op.span + ret.span + nextarg.span)
    end
    return ret
end




function next(x::EXPR, s::Iterator{:op})
    if length(x.args) == 2
        if s.i == 1
            return x.args[1], +s
        elseif s.i == 2
            return x.args[2], +s
        end
    else
        if s.i == 1
            return x.args[2], +s
        elseif s.i == 2
            return x.args[1], +s
        elseif s.i == 3 
            return x.args[3], +s
        end
    end
end

function next(x::EXPR, s::Iterator{:opchain})
    if isodd(s.i)
        return x.args[div(s.i + 1, 2) + 1], +s
    elseif s.i == 2
        return x.args[1], +s
    else 
        return x.punctuation[div(s.i, 2) - 1], +s
    end
end

function next(x::EXPR, s::Iterator{:syntaxcall})
    if length(x.args) == 1
        if s.i == 1 
            return x.head, +s
        else
            return x.args[1], +s
        end
    elseif s.n == 3
        if s.i == 1
            return x.args[1], +s
        elseif s.i == 2
            return x.head, +s
        elseif s.i == 3 
            return x.args[2], +s
        end
    else
        if s.i == 1
            return x.head, +s
        elseif s.i == 2
            return x.punctuation[1], +s
        elseif s.i == 3
            return x.args[1], +s
        elseif s.i == 4
            return x.punctuation[2], +s
        elseif s.i == 5
            return x.args[1], +s
        elseif s.i == 6
            return x.punctuation[3], +s
        end
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

function next(x::EXPR, s::Iterator{:prime})
    return (s.i == 1 ? x.args[s.i] : x.head), +s
end

function _start_where(x::EXPR)
    return Iterator{:where}(1, 1 + length(x.args) + length(x.punctuation))
end


function next(x::EXPR, s::Iterator{:where})
    if isempty(x.punctuation)
        if s.i == 1
            return x.args[1], +s
        elseif s.i ==2
            return x.head, +s
        else
            return x.args[2], +s
        end
    else
        if s.i == 1
            return x.args[1], +s
        elseif s.i == 2
            return x.head, +s
        elseif isodd(s.i)
            return x.punctuation[div(s.i - 1, 2)], +s
        elseif iseven(s.i)
            return x.args[div(s.i, 2)], +s
        end
    end
end
