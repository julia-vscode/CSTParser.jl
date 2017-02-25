# Generic blocks
#   begin
#   quote
#   do
#   let
#   toplevel (semicolon seperated expressions)

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BEGIN}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg], ps.nt.startbyte - start, [INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg], ps.nt.startbyte - start, [INSTANCE(ps)])
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.DO}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)
    return EXPR(kw, Expression[arg, block], ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)])
end


"""
    parseblocks(ps, ret = EXPR(BLOCK,...))

Parses an array of expressions (stored in ret) until 'end' is the next token. 
Returns `ps` the token before the closing `end`, the calling function is 
assumed to handle the closer.
"""
function parse_block(ps::ParseState, ret::EXPR = EXPR(BLOCK, [], 0))
    start = ps.nt.startbyte
    while ps.nt.kind!==Tokens.END
        push!(ret.args, @closer ps block parse_expression(ps))
    end
    @assert ps.nt.kind==Tokens.END
    ret.span = ps.nt.startbyte - start
    return ret
end




function next(x::EXPR, s::Iterator{:block})
    if !isempty(x.punctuation) && first(x.punctuation) isa PUNCTUATION{Tokens.COMMA}
        if isodd(s.i)
            return x.args[div(s.i + 1, 2)], +s
        else
            return x.punctuation[div(s.i, 2)], +s
        end
    elseif length(x.punctuation)==2
        if s.i == 1
            return x.punctuation[1], +s
        elseif s.i == s.n
            return x.punctuation[2], +s
        else
            return x.args[s.i-1], +s
        end
    end

    return x.args[s.i], +s
end

function next(x::EXPR, s::Iterator{:begin})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.punctuation[1], +s
    end
end


function next(x::EXPR, s::Iterator{:quote})
    if s.i == 1
        return x.punctuation[1], +s
    elseif s.i == s.n
        return x.punctuation[end], +s
    elseif s.i == 2
        if s.n == 4
            return x.punctuation[2], +s
        else
            return x.args[1], +s
        end
    elseif s.i == 3
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:toplevelblock})
    if isodd(s.i)
        return x.args[div(s.i+1, 2)], +s
    else
        return x.punctuation[div(s.i, 2)], +s
    end
end

