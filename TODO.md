# To do list




needs fixing
+ parsing kw, default values and splatting in function calls
+ interpolation
+ allow juxtaposition of number w/ identifier
+ dot operators
+ generators problem parsing `x.x for x in X`
+ special macrocall instance for Core.@doc case. requires different iterator.
+ multi ranges e.g. for i = 1:4, j = 2:4
+ parsing `x.$x` inside quote blocks
+ allow parsing but add error hint for assignment within tuples
+ assignment, give error if incorrect lhs and return block on rhs
+ fix `a ? b : c` syntax
+ only allow Core.@doc in toplevel scope
+ import/export/using of macros 

Operators
+ handle ';'
Unhandled 'head's
+ ccall
+ kw
+ parameters
+ stdcall
+ string
+ typed_comprehension
+ typed_vcat
+ vcat
+ vect


## Lexer errors
#### use '^' instead of '**'
#### invalid numeric constant "$number"
#### invalid use of '_' in numeric constant
#### invalid numeric constant "$number"
disallow digits after binary or octal literals, e.g. 0b12
#### incomplete: unterminated multi-line comment #= ... =#
if we hit ENDOF during comment lexing
#### '\\r' not followed by '\\n' is invalid
#### invalid operator ..$op
`..` followed by an operator is invalid
#### invalid operator \".!\"
#### invisible character
JuliaParser.Lexer.is_ignorable_char(c)


## Parser errors
#### "colon expected in \"?\" expression"
expected format: condition ? val1 : val2
#### unexpected $token in $type expression
#### extra token $token after end of expression
usually due to expecting a newline after the end of an expression
#### missing last argument in range expression
#### line break in : expression
#### invalid $arg in range expression. Did you mean $arg:?
#### unexpected $token
#### incomplete: $resword requires end
#### elseif without preceding if
#### missing condition in if/elseif
#### use elseif instead of else if
#### unexpected $token in if expression
#### let variable should end in ; or newline
#### invalid type name
if conflicts with reserved words
#### unexpected $token in try expression
#### expected assignment after $word

