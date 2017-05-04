module Diagnostics
abstract type Format end
abstract type Lint end
abstract type Action end

mutable struct Diagnostic{C}
    loc::UnitRange
    actions::Vector{Action}
end
Diagnostic(r::UnitRange) = Diagnostic(r, [])

@enum(FormatCodes,
Useelseif,
Indents,
CamelCase,
LowerCase,
MissingWS,
ExtraWS,
CommaWS)

@enum(LintCodes,
DuplicateArgumentName,
ArgumentFunctionNameConflict,
SlurpingPosition, 
KWPosition,
ImportInFunction,
DuplicateArgument,
LetNonAssignment,
RangeNonAssignment,
CondAssignment,
DeadCode,
DictParaMisSpec,
DictGenAssignment,
MisnamedConstructor,
LoopOverSingle,
AssignsToFuncName,
PossibleTypo,

Deprecation,
functionDeprecation,
typeDeprecation,
immutableDeprecation,
abstractDeprecation,
bitstypeDeprecation,
typealiasDeprecation)

struct Deletion <: Action
    range::UnitRange
end

struct AddWS <: Action
    range::UnitRange
    length::Int
end

# function apply(hints::Vector{Diagnostic}, str)
#     str1 = deepcopy(str)
#     ng = length(hints)
#     for i = ng:-1:1
#         str1 = apply(hints[i], str1)
#     end
#     str1
# end

# function apply(h::Diagnostic, str) 
#     return str
# end

# function apply(h::Diagnostic{AddWhiteSpace}, str)
#     if h.loc isa Tuple
#         # loc = ind2chr(str, h.loc[1])
#         str = string(str[1:h.loc[1]], " "^h.loc[2], str[h.loc[1] + 1:end])
#     else
#         # loc = ind2chr(str, h.loc)
#         str = string(str[1:h.loc], " ", str[h.loc + 1:end])
#     end
# end

# function apply(h::Diagnostic{DeleteWhiteSpace}, str)
#     s1 = ind2chr(str, first(h.loc))
#     s2 = ind2chr(str, last(h.loc) + 1)
#     str = string(str[1:s1], str[s2:end])
# end
end

# Formatting

islbracket(t::Token) = t.kind == Tokens.LPAREN ||
                        t.kind == Tokens.LBRACE ||
                        t.kind == Tokens.LSQUARE

isrbracket(t::Token) = t.kind == Tokens.RPAREN ||
                        t.kind == Tokens.RBRACE ||
                        t.kind == Tokens.RSQUARE

function format_op(ps, prec)
    !ps.formatcheck && return
    loc = ps.t.startbyte:ps.t.endbyte + 1
    actions = Diagnostics.Action[]
    if (prec == ColonOp || prec == PowerOp || prec == DeclarationOp || prec == DotOp) && ps.t.kind != Tokens.ANON_FUNC
        ht = Diagnostics.ExtraWS
        if ps.lws.kind != EmptyWS
            push!(actions, Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte))
        end
        if ps.ws.kind != EmptyWS
            push!(actions, Diagnostics.Deletion(ps.ws.startbyte:ps.nt.startbyte))
        end
    elseif ps.t.kind == Tokens.ISSUBTYPE || ps.t.kind == Tokens.DDDOT
    else
        ht = Diagnostics.MissingWS
        if ps.lws.kind == EmptyWS
            push!(actions, Diagnostics.AddWS(ps.t.startbyte:ps.t.startbyte, 1))
        end
        if ps.ws.kind == EmptyWS
            push!(actions, Diagnostics.AddWS(ps.nt.startbyte:ps.nt.startbyte, 1))
        end
    end
    if !isempty(actions)
        push!(ps.diagnostics, Diagnostic{ht}(loc, actions))
    end
end

function format_comma(ps)
    !ps.formatcheck && return
    if ps.lws.kind != EmptyWS && !(islbracket(ps.lt))
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte + (0:1), [Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte)]))
    end
    if ps.ws.kind == EmptyWS && !(isrbracket(ps.nt))
        push!(ps.diagnostics, Diagnostic{Diagnostics.MissingWS}(ps.t.startbyte + (0:1), [Diagnostics.AddWS(ps.nt.startbyte:ps.nt.startbyte, 1)]))
    end
end

function format_lbracket(ps)
    !ps.formatcheck && return
    if ps.ws.kind != EmptyWS
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte + 1:ps.nt.startbyte, [Diagnostics.Deletion(ps.lws.startbyte:ps.nt.startbyte)]))
    end
end

function format_rbracket(ps)
    !ps.formatcheck && return
    if ps.lws.kind != EmptyWS
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte + (0:1), [Diagnostics.Deletion(ps.lws.startbyte:ps.t.endbyte)]))
    end
end

function format_indent(ps, start_col)
    !ps.formatcheck && return
    if (start_col > 0 && ps.nt.startpos[2] != start_col)
        dindent = start_col - ps.nt.startpos[2]
        if dindent > 0
            push!(ps.diagnostics, Diagnostic{Diagnostics.MissingWS}(ps.nt.startbyte + (0:dindent), []))
        else
            push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.nt.startbyte + (dindent + 1:0), []))
        end
    end
end

function format_typename(ps, sig)
    !ps.formatcheck && return
#     start_loc = ps.nt.startbyte - sig.span
#     id = get_id(sig)
#     sig isa EXPR && return
#     val = string(id.val)
#     # Abitrary limit of 3 for uppercase acronym
#     if islower(first(val)) || (length(val) > 3 && all(isupper, val))
#         push!(ps.diagnostics, Diagnostic{Diagnostics.CamelCase}(start_loc + (1:sizeof(val))))
#     end
end

function format_funcname(ps, id, offset)
    !ps.formatcheck && return
    # start_loc = ps.nt.startbyte - offset
    # !(id isa Symbol) && return
    # val = string(id)
    # if !islower(val) #!all(islower(c) || isdigit(c) || c == '!' for c in val)
    #     push!(ps.diagnostics, Diagnostic{Diagnostics.LowerCase}(start_loc + (1:sizeof(val))))
    # end
end
