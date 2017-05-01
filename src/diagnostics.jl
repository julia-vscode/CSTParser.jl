module Diagnotics

abstract type Action end

struct AddWhiteSpace <: Action
    range::UnitRange
end

struct DeleteWhiteSpace <: Action
    range::UnitRange
end

abstract type DiagnosticSeverity end
abstract type Error <: DiagnosticSeverity end
abstract type Warning <: DiagnosticSeverity end
abstract type Information <: DiagnosticSeverity end
abstract type Hint <: DiagnosticSeverity end

struct Diagnostic{S} 
    loc::UnitRange
    code::Int
    action::Vector{Action}
end

@enum(ErrorCodes,
)

@enum(WarningCodes,
# Deprecations
Deprecationfunction,
Deprecationtype,
Deprecationimmutable,
Deprecationabstract,
Deprecationbitstype,
Deprecationtypealias,
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
PossibleTypo)


end


