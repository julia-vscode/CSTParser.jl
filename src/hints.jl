module Hints
abstract Format
abstract Lint
type Hint{C}
    loc
end

@enum(FormatCodes,
AddWhiteSpace,
DeleteWhiteSpace,
Useelseif,
Indents)

@enum(LintCodes,
DuplicateArgumentName,
ArgumentFunctionNameConflict,
SlurpingPosition, 
KWPosition,
ImportInFunction)


function applyhints(hints::Vector{Hint}, str)
    str1 = deepcopy(str)
    ng = length(hints)
    for i = ng:-1:1
        h = hints[i]
        if h isa Hints.Hint{Hints.AddWhiteSpace}
            str1 = apply(h, str1)
        end
    end
    str1
end

function apply(h::Hints.Hint{Hints.AddWhiteSpace}, str)
    loc = ind2chr(str, h.loc)
    str = string(str[1:loc], " ", str[loc+1:end])
end

end