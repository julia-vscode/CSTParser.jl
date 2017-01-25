# To do list

Operators
+ parse colon/range
+ parse dot access
+ parse arrows
+ ? syntax
+ assignment, give error if incorrect lhs and return block on rhs


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




## Reserved word
#### TRUE/FALSE
These become an `instance`.

#### BREAK
This becomes an `instance`.
#### CONTINUE
This becomes an `instance`.

### Prefix keywords
#### CONST
`Prefix`
#### EXPORT
`Prefix`
#### GLOBAL
`Prefix`
#### IMPORT
`Prefix`
#### IMPORTALL
`Prefix`
#### LOCAL
`Prefix`
#### RETURN
`Prefix`
#### USING
`Prefix`


### Single line definitions
#### ABSTRACT
#### BITSTYPE
#### IMMUTABLE
#### TYPEALIAS


### `end` blocks
#### BAREMODULE
#### BEGIN
#### BEGINWHILE
#### DO
#### FOR
#### FUNCTION
#### LET
#### MACRO
#### MODULE
#### QUOTE
#### TYPE

#### IF
#### ELSE
#### ELSEIF


#### END

#### TRY
#### CATCH
#### FINALLY



