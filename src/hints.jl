module Diagnostics

abstract type Format end
abstract type Lint end
abstract type Action end

mutable struct Diagnostic{C}
    loc::UnitRange
    actions::Vector{Action}
    message::String
end
Diagnostic(r::UnitRange) = Diagnostic(r, [], "")

@enum(ErrorCodes,
UnexpectedLParen,
UnexpectedRParen,
UnexpectedLBrace,
UnexpectedRBrace,
UnexpectedLSquare,
UnexpectedRSquare,
UnexpectedInputEnd,
UnexpectedComma,
UnexpectedOperator,
UnexpectedIdentifier,
ParseFailure)

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
typealiasDeprecation,
parameterisedDeprecation)

struct Deletion <: Action
    range::UnitRange
end

struct AddWS <: Action
    range::UnitRange
    length::Int
end

struct TextEdit <: Action
    range::UnitRange
    text::String
end

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
    if (prec == ColonOp || prec == PowerOp || prec == DeclarationOp || prec == DotOp) && ps.t.kind != Tokens.ANON_FUNC && ps.t.kind != Tokens.PRIME
        if ps.lws.kind != EmptyWS && ps.ws.kind != EmptyWS
            diag = Diagnostic{Diagnostics.ExtraWS}(loc, Diagnostics.Action[Diagnostics.Deletion(ps.ws.startbyte:ps.nt.startbyte),Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte)], "Unexpected white space around operator")
            push!(ps.diagnostics, diag)
        elseif ps.lws.kind != EmptyWS
            diag = Diagnostic{Diagnostics.ExtraWS}(loc, Diagnostics.Action[Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte)], "Unexpected white space around operator")
            push!(ps.diagnostics, diag)
        elseif ps.ws.kind != EmptyWS
            diag = Diagnostic{Diagnostics.ExtraWS}(loc, Diagnostics.Action[Diagnostics.Deletion(ps.ws.startbyte:ps.nt.startbyte)], "Unexpected white space around operator")
            push!(ps.diagnostics, diag)
        end
    elseif ps.t.kind == Tokens.PRIME
        if ps.lws.kind != EmptyWS
            diag = Diagnostic{Diagnostics.ExtraWS}(loc, Diagnostics.Action[Diagnostics.Deletion(ps.ws.startbyte:ps.nt.startbyte),Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte)], "Unexpected white space around operator")
            push!(ps.diagnostics, diag)
        end
    elseif ps.t.kind == Tokens.ISSUBTYPE || ps.t.kind == Tokens.DDDOT
    else
        if ps.lws.kind == EmptyWS && ps.ws.kind == EmptyWS
            diag = Diagnostic{Diagnostics.MissingWS}(loc, Diagnostics.Action[Diagnostics.AddWS(ps.nt.startbyte:ps.nt.startbyte, 1),Diagnostics.AddWS(ps.t.startbyte:ps.t.startbyte, 1)], "Missing white space around operator")
            push!(ps.diagnostics, diag)
        elseif ps.lws.kind == EmptyWS
            diag = Diagnostic{Diagnostics.MissingWS}(loc, Diagnostics.Action[Diagnostics.AddWS(ps.t.startbyte:ps.t.startbyte, 1)], "Missing white space around operator")
            push!(ps.diagnostics, diag)
        elseif ps.ws.kind == EmptyWS
            diag = Diagnostic{Diagnostics.MissingWS}(loc, Diagnostics.Action[Diagnostics.AddWS(ps.nt.startbyte:ps.nt.startbyte, 1)], "Missing white space around operator")
            push!(ps.diagnostics, diag)
        end
    end
end

function format_comma(ps)
    !ps.formatcheck && return
    if ps.lws.kind != EmptyWS && !(islbracket(ps.lt))
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte + (0:1), [Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte)], "Unexpected white space preceding comma"))
    end
    if ps.ws.kind == EmptyWS && !(isrbracket(ps.nt))
        push!(ps.diagnostics, Diagnostic{Diagnostics.MissingWS}(ps.t.startbyte + (0:1), [Diagnostics.AddWS(ps.nt.startbyte:ps.nt.startbyte, 1)], "Missing white space following comma"))
    end
end

function format_lbracket(ps)
    !ps.formatcheck && return
    if ps.ws.kind == WS
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte + (0:1), [Diagnostics.Deletion(ps.ws.startbyte:ps.nt.startbyte)], "Unexpected white space following $(ps.t.val)"))
    end
end

function format_rbracket(ps)
    !ps.formatcheck && return
    if ps.lws.kind == WS
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte + (0:1), [Diagnostics.Deletion(ps.lws.startbyte:ps.t.startbyte)], "Unexpected white space preceding $(ps.t.val)"))
    end
end

function format_indent(ps, start_col)
    !ps.formatcheck && return
    if (start_col > 0 && ps.nt.startpos[2] != start_col)
        dindent = start_col - ps.nt.startpos[2]
        if dindent > 0
            push!(ps.diagnostics, Diagnostic{Diagnostics.MissingWS}(ps.nt.startbyte + (0:dindent), [Diagnostics.AddWS(ps.nt.startbyte:ps.nt.startbyte, dindent)], ""))
        else
            push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.nt.startbyte + (dindent + 1:0), [Diagnostics.Deletion(ps.nt.startbyte + (dindent:0))], ""))
        end
    end
end

function format_kw(ps)
    !ps.formatcheck && return
    if ps.ws.kind == WS
        if length(ps.ws.val) > 1
            push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte:ps.nt.startbyte, [Diagnostics.Deletion(ps.ws.startbyte + 1:ps.nt.startbyte)], ""))
        end
    end
end

function format_no_rws(ps)
    !ps.formatcheck && return
    if ps.ws.kind != EmptyWS
        push!(ps.diagnostics, Diagnostic{Diagnostics.ExtraWS}(ps.t.startbyte:ps.nt.startbyte, [Diagnostics.Deletion(ps.ws.startbyte:ps.nt.startbyte)], ""))
    end
end

function format_typename(ps, sig)
    !ps.formatcheck && return
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

function error_unexpected(ps, startbyte, tok)
    if tok.kind == Tokens.ENDMARKER
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedInputEnd}(
            tok.startbyte:tok.endbyte, [], "Unexpected end of input"
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected end of input")
    elseif tok.kind == Tokens.COMMA
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedComma}(
            tok.startbyte:tok.endbyte, [], "Unexpected comma"
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected comma")
    elseif tok.kind == Tokens.LPAREN
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedLParen}(
            tok.startbyte:tok.endbyte, [], "Unexpected ("
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected (")
    elseif tok.kind == Tokens.RPAREN
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedRParen}(
            tok.startbyte:tok.endbyte, [], "Unexpected )"
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected )")
    elseif tok.kind == Tokens.LBRACE
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedLBrace}(
            tok.startbyte:tok.endbyte, [], "Unexpected {"
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected {")
    elseif tok.kind == Tokens.RBRACE
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedRBrace}(
            tok.startbyte:tok.endbyte, [], "Unexpected }"
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected }")
    elseif tok.kind == Tokens.LSQUARE
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedLSquare}(
            tok.startbyte:tok.endbyte, [], "Unexpected ["
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected [")
    elseif tok.kind == Tokens.RSQUARE
        ps.errored = true
        push!(ps.diagnostics, Diagnostic{Diagnostics.UnexpectedRSquare}(
            tok.startbyte:tok.endbyte, [], "Unexpected ]"
        ))
        return EXPR{ERROR}(EXPR[INSTANCE(ps)], 0, Variable[], "Unexpected ]")
    else
        error("Internal error")
    end
end