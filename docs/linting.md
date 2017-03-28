# Linting

## Basic
[] use of undeclared variable.
### `call`
### `ref`
[] check for `[1 :end]` typos.
### `tuple`
[] assignment inside tuple.

## Declarationsc
### `function`
[] repeated args.
[] func/args name conflict.
[] ellipsis not on end arg.
[] default variable positioning.
[] parameters positioning.
[] deadcode following `return`.
[] unused argument.
[] use of undeclared variable.
[] use of local variable that conflicts with func. name.

### `abstract` (`abstract type`)
### `bitstype` (`primitive type`)

### `type\immutable` (`(mutable) struct`)

[] inner constructor with wrong number of arguments.
[] missing `new` in inner constructor.
[] misspelled constructor name.

### `macro`
### `module`/`baremodule`
### `typealias`

## Control Flow 
### `block`
### `for`
[x] Non assignment in range(s).

### `if`
[x] check for assignment in conditional.
[x] constant conditional, deadcode.
[] deadcode following `return`.

### `let`
[x] Check for assignment in signature.
### `try`
### `while`
[x] Check for mistaken assignment in signature.
[x] Check for deadcode.

## Imports
### `export`
[x] duplication.
[] exporting non-defined symbols.
[x] Not allowed in functions.
### `import`
[x] Not allowed in functions.
### `importall`
[x] Not allowed in functions.
### `using`
[x] Not allowed in functions.

## Generators
### `generator`
[x] Non assignment in range(s).
### `comprehension`
[x] Non assignment in range(s).
### `typed_comprehension`
[x] Non assignment in range(s).
### `flatten`
### `filter`

## Misc.
### `do`
### `quote`
### `row`
### `hcat`
### `typed_hcat`
### `vcat`
### `typed_vcat`
### `vect`
### `toplevel`
### `string`

## Types
### `<:`
### `curly`
### `where`

## `Dicts`
[x] If paramaterised, ensure two parameters.
[] Ensure pair assignment for all arguments.
[x] Ensure pair assignment if generator.
[] If keys are `literal`s check for type consistency and consistency with parameterisation.
[] Duplicate keys.
[] check for type uniformity.
[] check for tuple syntax when used as an iterator.


