Expression is used to refer to any `EXPR` object, including those without children (terminals).

```
mutable struct EXPR
    head::Symbol
    args::Union{Nothing,Vector{EXPR}}
    trivia::Union{Nothing,Vector{EXPR}}
    fullspan::Int
    span::Int
    val::Union{Nothing,String}
    parent::Union{Nothing,EXPR}
    meta
end
```
The first two arguments match the representation within `Expr`.
## `head`
The type of expression, equivalent to the head of Expr. Possible heads are a superset of those available for an Expr.

## `args`
As for `Expr`, holds child expressions. Terminal expressions do not hold children.

## `trivia`
Holds terminals specific to the CST representation. Terminal expressions do not hold trivia.

## `fullspan`
The byte size of the expression in the source code text, including trailing white space.

## `span`
As above but excluding trailing white space. (`fullspan - span` is the byte size of trailing white space.)

## `val`
A field to store the textual representation of the token as necessary, otherwise it is set to `nothing`. This is needed for identifiers, operators and literals.


# Heads
An extended group of expression types is used to allow full equivalence of terminal tokens with other expressions. By convention expression heads will match those used in Julia AST (lowercase) and others are capitalised.

## Terminals
Identifier
Nonstdidentifier
Operator

### Punctuation
comma
lparen
rparen
lsquare
rsquare
lbrace
rbrace
atsign
dot
      
### Keywords
abstract
baremodule
begin
break
catch
const
continue
do
else
elseif
end
export
finally
for
function
global
if
import
importall
let
local
macro
module
mutable
new
outer
primitive
quote
return
struct
try
type
using
while

### Literals
:INTEGER,
:BININT,
:HEXINT,
:OCTINT,
:FLOAT,
:STRING,
:TRIPLESTRING,
:CHAR,
:CMD,
:TRIPLECMD,
:NOTHING,
:true,
:false,

# Expressions
##### Const
Trivia: `const`
##### Global
Length: 2
Trivia: `global`
Iter order: t, a
##### Local
Length: 2
Trivia: `local`
Iter order: t, a
##### Return
Length: 2
Trivia: `return`
Iter order: t, a
##### Abstract
Trivia: `abstract`, `type`, `end`
##### Begin
Trivia: `begin`, `end`
##### Block
Trivia: nothing
##### For
Trivia: `for`, `end`
##### Function
Trivia: `function`, `end`



##### Outer
##### Call
##### ChainOpCall
##### ColonOpCall
##### Braces
##### BracesCat
##### Comparison
##### Curly
##### Do
##### Filter
##### Flatten
##### Generator
##### GlobalRefDoc
##### If
##### Kw
Trivia: nothing
##### Let
##### Macro
##### MacroCall
##### MacroName
##### Mutable

##### Parameters
##### Primitive
##### Quote
##### Quotenode
##### InvisBrackets
##### String
##### Struct
##### Try
##### Tuple
##### File

##### While
##### x_Cmd
##### x_Str
##### Module
Trivia: `module`, `end`
##### BareModule
Trivia: `baremodule`, `end`
##### TopLevel
##### Export
##### Import
##### Using
##### Comprehension
##### Dict_Comprehension
##### Typed_Comprehension
##### Hcat
##### Typed_Hcat
##### Ref
##### Row
##### Vcat
##### Typed_Vcat
##### Vect

## Head's not present in `Expr`
:ErrorToken

## Iterators
Iterators of loops are converted to `a = b` if needed in line with the scheme parser. the operator is a facade and the actual operator use  is stored as trivia.


# Decisions
1. For single token keyword expressions (e.g. `break`) do we use the visible token as the head or store it in trivia?