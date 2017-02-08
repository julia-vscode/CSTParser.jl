# To do list

Operators
+ assignment, give error if incorrect lhs and return block on rhs
+ handle ';'
+ multi ranges e.g. for i = 1:4, j = 2:4
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




## Keywords
---
#### `true`, `false`, `break`, `continue`
- These all become symbols. 
- Linting for the latter two requires `for`/`while` context.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y | y | 


---
#### `const`, `global`, `local`, `return`
- These become keyword blocks with 1 argument.
- Linting for `return` require `function` context.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y | y | 

---
#### `import`, `importall`, `using`
- These all parse in the same way. Several forms: 
1. `import a`
2. `import a.b`
3. `import a, b, c`
4. `import a, b.c`
5. `import a: b`
6. `import a: b, c`
7. `import a: b, c.d`
- Cases with a colon and only one seperating comma are parsed as though the colon is a dot.
- Other cases with a colon parse as a `toplevel` expression with as many arguments as there are comma seperated expressions after the colon. All of these arguments are dot seperated lists of symbols which share the first `n` symbols in their names where `n` is the number of pre-colon symbols.
- Punctuation is stored `[(.) (:) (,)]`

parse | iterable | test | lint 
--- | --- | --- | ---
~ | ~ | ~ | 

---
#### `export`
- Parses to a comma seperated list of symbols.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y | y | 


---
#### `abstract`
- Parses as a keyword block with one argument.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y | y | 


---
#### `bitstype`, `typealias`
- Parses as a keyword block with two arguments.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y | y | 


---
#### `module`, `baremodule`
- Parse as keyword blocks 

parse | iterable | test | lint 
--- | --- | --- | ---
y | y |  | 


---
#### `begin`
- Parses as a keyword block with `n` arguments.
- When used for storage in another keyword block the head has 0 span and 
punctuation (the closing end) is not stored.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y |  | 


---
#### `quote`
- Parses as a keyword block containing a `block` expression.

parse | iterable | test | lint 
--- | --- | --- | ---
y |  |  | 


---
#### `for`, `while`
- Parsed as keyword block with 2 arguments.
- Punctuation: `end`.

parse | iterable | test | lint 
--- | --- | --- | ---
y |  |  | 


---
#### `type`, `immutable`
- Parsed as keyword, name, block and `end`.
- 
- Punctuation: `end`.

parse | iterable | test | lint 
--- | --- | --- | ---
y | y | y | 


---
#### `function`

parse | iterable | test | lint 
--- | --- | --- | ---
 |  |  | 


---
#### `macro`

parse | iterable | test | lint 
--- | --- | --- | ---
 |  |  | 


---
#### `do`

parse | iterable | test | lint 
--- | --- | --- | ---
 |  |  | 


---
#### `let`

parse | iterable | test | lint 
--- | --- | --- | ---
 |  |  | 


---
#### `if`

parse | iterable | test | lint 
--- | --- | --- | ---
 |  |  | 


----
#### `try`

parse | iterable | test | lint 
--- | --- | --- | ---
 |  |  | 






