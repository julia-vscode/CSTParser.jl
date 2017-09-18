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
UnexpectedStringEnd,
UnexpectedCommentEnd,
UnexpectedBlockEnd,
UnexpectedCmdEnd,
UnexpectedCharEnd,
UnexpectedComma,
UnexpectedOperator,
UnexpectedIdentifier,
ParseFailure)

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


end


function make_error(ps, range, code, text)
    ps.errored = true
    ps.error_code = code
    push!(ps.diagnostics, Diagnostic{code}(range, [], text))
    return EXPR{ERROR}(Any[INSTANCE(ps)])
end

function error_unexpected(ps, tok)
    if tok.kind == Tokens.ENDMARKER
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedInputEnd,
                          "Unexpected end of input")
    elseif tok.kind == Tokens.COMMA
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedComma,
                          "Unexpected comma")
    elseif tok.kind == Tokens.LPAREN
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedLParen,
                          "Unexpected (")
    elseif tok.kind == Tokens.RPAREN
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedRParen,
                          "Unexpected )")
    elseif tok.kind == Tokens.LBRACE
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedLBrace,
                          "Unexpected {")
    elseif tok.kind == Tokens.RBRACE
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedRBrace,
                          "Unexpected }")
    elseif tok.kind == Tokens.LSQUARE
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedLSquare,
                          "Unexpected [")
    elseif tok.kind == Tokens.RSQUARE
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedRSquare,
                         "Unexpected [")
    elseif tok.kind == Tokens.ERROR
        return make_error(ps, tok.startbyte:tok.endbyte, Diagnostics.UnexpectedRSquare,
                            "Unexpected token $(val(tok, ps))")
    else
        error("Internal error")
    end
end

function error_eof(ps, byte, kind=Diagnostics.UnexpectedInputEnd, text="Unexpected end of input")
    return make_error(ps, byte:byte, kind, text)
end

function error_token(ps, tok)
    if tok.token_error == Tokens.EOF_STRING
        return error_eof(ps, ps.t.endbyte+1, Diagnostics.UnexpectedStringEnd, "Unexpected end of string")
    elseif tok.token_error == Tokens.EOF_MULTICOMMENT
        return error_eof(ps, ps.t.endbyte+1, Diagnostics.UnexpectedCommentEnd, "Unexpected end of multiline comment")
    elseif tok.token_error == Tokens.EOF_CHAR
        return error_eof(ps, ps.t.endbyte+1, Diagnostics.UnexpectedCharEnd, "Unexpected end of character literal")
    elseif tok.token_error == Tokens.EOF_CMD
        return error_eof(ps, ps.t.endbyte+1, Diagnostics.UnexpectedCmdEnd, "Unexpected end of command")
    else
        ps.errored = true
        return EXPR{ERROR}(Any[INSTANCE(ps)])
    end
end
