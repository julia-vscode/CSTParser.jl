function parse_kw(ps::ParseState, ::Type{Val{Tokens.FOR}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte ranges = @default ps parse_ranges(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)
    next(ps)
    ret = EXPR{For}(EXPR[kw, ranges, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")

    # Linting
    # if ranges isa EXPR && ranges.head == BLOCK
    #     for r in ranges.args
    #         _lint_range(ps, r, startbyte + kw.span + (0:ranges.span))
    #     end
    # else
    #     _lint_range(ps, ranges, startbyte + kw.span + (0:ranges.span))
    # end

    return ret
end

function _lint_range(ps::ParseState, x, loc)
    if x isa EXPR{BinaryOpCall} && ((x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.IN,false}} || x.args[2] isa EXPR{OPERATOR{ComparisonOp,Tokens.ELEMENT_OF,false}}))
        if x.args[2] isa IDENTIFIER
            id = Expr(x.args[2])
            t = infer_t(x.args[3])
            push!(x.defs, Variable(id, t, x))
        end
        if x.args[3] isa LITERAL
            push!(ps.diagnostics, Diagnostic{Diagnostics.LoopOverSingle}(loc, []))
        end
        
    elseif x isa EXPR{BinarySyntaxOpCall} && x.head isa EXPR{OPERATOR{AssignmentOp,Tokens.EQ,false}}
        if x.args[2] isa LITERAL
            push!(ps.diagnostics, Diagnostic{Diagnostics.LoopOverSingle}(loc, []))
        end
    else
        push!(ps.diagnostics, Diagnostic{Diagnostics.RangeNonAssignment}(loc, []))
    end
end

function parse_ranges(ps::ParseState)
    startbyte = ps.nt.startbyte
    
    arg = @closer ps range @closer ps comma @closer ps ws parse_expression(ps)
    if ps.nt.kind == Tokens.COMMA
        arg = EXPR{Block}(EXPR[arg], arg.span, Variable[], "")
        while ps.nt.kind == Tokens.COMMA
            next(ps)
            push!(arg.args, INSTANCE(ps))
            format_comma(ps)

            arg.span += last(arg.args).span
            @catcherror ps startbyte push!(arg.args, @closer ps comma @closer ps ws parse_expression(ps))
            arg.span += last(arg.args).span
        end
    end
    return arg
end


function parse_kw(ps::ParseState, ::Type{Val{Tokens.WHILE}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    @catcherror ps startbyte cond = @default ps @closer ps ws parse_expression(ps)
    @catcherror ps startbyte block = @default ps parse_block(ps, start_col)
    next(ps)

    ret = EXPR{While}(EXPR[kw, cond, block, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")

    # Linting
    if cond isa EXPR{BinarySyntaxOpCall} && cond.args[2] isa EXPR{OPERATOR{AssignmentOp,k1,d1}} where {k1,d1}
        push!(ps.diagnostics, Diagnostic{Diagnostics.CondAssignment}(startbyte + kw.span + (0:cond.span), []))
    end
    if cond isa EXPR{LITERAL{Tokens.FALSE}}
        push!(ps.diagnostics, Diagnostic{Diagnostics.DeadCode}(startbyte:ps.nt.startbyte, []))
    end

    return ret
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BREAK}})
    return EXPR{Break}(EXPR[INSTANCE(ps)], ps.nt.startbyte - ps.t.startbyte, Variable[], "")
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.CONTINUE}})
    return EXPR{Continue}(EXPR[INSTANCE(ps)], ps.nt.startbyte - ps.t.startbyte, Variable[], "")
end

