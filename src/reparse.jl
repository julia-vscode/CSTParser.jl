
const EXPRStack = Tuple{EXPR,Int,Int}

function find_enclosing_expr(cst, offset, pos = 0, stack = EXPRStack[])
    pos1 = pos
    for (i, a) in enumerate(cst)
        if pos < first(offset) < pos + a.span && pos < last(offset) < pos + a.span
            push!(stack, (cst, pos1, i))
            return find_enclosing_expr(a, offset, pos, stack)
        else 
            pos += a.fullspan
        end
    end
    push!(stack, (cst, pos1, 0))
    return stack
end

containing_expr(stack) = first(last(stack))
parent_expr(stack) = first(stack[end - 1])
insert_size(inserttext, insertrange) = sizeof(inserttext) - max(last(insertrange) - first(insertrange), 0)
enclosing_expr_range(stack, insertsize) = last(stack)[2] .+ (1:first(last(stack)).fullspan + insertsize)

function reparse(edittedtext::String, inserttext::String, insertrange::UnitRange{Int}, oldcst)
    #need to handle empty replacement case, i.e. inserttext = ""
    stack = find_enclosing_expr(oldcst, insertrange)
    insertsize = insert_size(inserttext, insertrange)
    reparsed = reparse(stack, edittedtext, insertsize, oldcst)
    return reparsed, oldcst
end


function replace_args!(replacement_args, stack)
    pexpr, ppos, pi = stack[end - 1]
    oldspan, oldfullspan = pexpr.args[pi].span, pexpr.args[pi].fullspan
    if length(replacement_args) > 1
        deleteat!(pexpr.args, pi)
        for i = 0:length(replacement_args) - 1
            insert!(pexpr.args, pi + i, replacement_args[1 + i])
        end
    else
        pexpr.args[pi] = replacement_args[1]
        dfullspan = replacement_args[1].fullspan - oldfullspan
        @info "Replacing $(typeof(pexpr)) at $(pi)"
        fix_stack_span(stack, dfullspan, replacement_args[1].span - replacement_args[1].fullspan)
    end 
end

function reparse(stack::Array{EXPRStack}, edittedtext::String, insertsize::Int, oldcst)
    # Assume no existing error in CST
    # need to update (full)spans
    if length(stack) == 1
        return false
    else
        if parent_expr(stack) isa EXPR{FileH} 
            replacement_args = parse(edittedtext[enclosing_expr_range(stack, insertsize)], true).args
        elseif parent_expr(stack) isa EXPR{Block} && !(length(stack) > 2 && stack[end - 2] isa EXPR{If})
            replacement_args = let 
                ps = ParseState(edittedtext[enclosing_expr_range(stack, insertsize)])
                newblockargs = Any[]
                CSTParser.parse_block(ps, newblockargs)
            end
        else
            pop!(stack)
            return reparse(stack, edittedtext, insertsize, oldcst)
        end
        replace_args!(replacement_args, stack)
        return true
    end
    return false
end

function fixlastchild(x, pi, dspan)
    nx = length(x)
    if pi == nx
        x[pi] = x.fullspan - dspan
        return true
    elseif x[nx].fullspan == 0 
        for i = nx - 1:-1:1
            if x[i].fullspan > 0
                x[pi] = x.fullspan - dspan
                return true
            end
        end
    end
    return false
end

function fix_stack_span(stack::Array{EXPRStack}, dfullspan, dspan)
    islast = true
    for i = length(stack) - 1:-1:1
        stack[i][1].fullspan += dfullspan
        if islast && stack[i][3] == length(stack[i][1])
            stack[i][1].span = stack[i][1].fullspan + dspan
        else
            stack[i][1].span += dfullspan
            islast = false
        end
    end
end

function reparse_test(text, insertrange, inserttext)
    cst = parse(text, true) 
    cst0 = deepcopy(cst)
    edittedtext = edit_string(text, insertrange, inserttext)
    reparsed, reparsed_cst = reparse(edittedtext, inserttext, insertrange, cst)
    new_cst = CSTParser.parse(edittedtext, true)
    return reparsed, isequiv(new_cst, reparsed_cst), text, edittedtext, cst0, new_cst, reparsed_cst
end

function edit_string(text, insertrange, inserttext)
    if first(insertrange) == last(insertrange) == 0
        text = string(inserttext, text)
    elseif first(insertrange) == 0 && last(insertrange) == sizeof(text)
        text = inserttext
    elseif first(insertrange) == 0
        text = string(inserttext, text[nextind(text, last(insertrange)):end])
    elseif first(insertrange) == last(insertrange) == sizeof(text)
        text = string(text, inserttext)
    elseif last(insertrange) == sizeof(text)
        text = string(text[1:first(insertrange)], inserttext)
    else
        text = string(text[1:first(insertrange)], inserttext, text[nextind(text, last(insertrange)):end])
    end    
end

spanequiv(a::EXPR, b::EXPR) = a.span == b.span && a.fullspan == b.fullspan
 
isequiv(a, b; span = true) = false

function isequiv(a::EXPR, b::EXPR; span = true)
    t = typof(a) === typof(b)
    typeof(a.args) != typeof(b.args) && return false
    if a.args isa Vector
        length(a.args) != length(b.args) && return false
        for i = 1:length(a.args)
            t = t && isequiv(a.args[i], b.args[i], span = span) 
            t || return false
        end
    end
    return (!span || spanequiv(a, b))
end
