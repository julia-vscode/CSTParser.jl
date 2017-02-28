# Parser.jl (wip)

A parser for Julia using [Tokenize](https://github.com/KristofferC/Tokenize.jl/) that aims to extend the built-in parser by providing additional meta information along with the resultant AST. It is incomplete though can currently parse roughly 75% of `.../base/`.

### Additional Output
<!--The [Tokenize](https://github.com/KristofferC/Tokenize.jl/) package is used to lex source files and-->
- `EXPR`'s (the internal equivalent of `Core.Expr`) are iterable producing children in the order that they appear in the source code, including punctuation. Example: 
```
f(x) = x*2 -> [f(x), =, x*2]
f(x) -> [f, (, x, )]
```
- The byte span of each `EXPR` is stored allowing a mapping between byte position in the source code and the releveant parsed expression. The span of a single token includes any trailing whitespace, newlines or comments. This also allows for fast partial parsing of modified source code.
- Formatting hints are generated as the source code is parsed (e.g. mismatched indents for blocks, missing white space around operators). 
- The declaration of functions, datatypes and variables are tracked and stored in the relevant hierarchical scopes attatched to the expressions that declare the scope. This allows for a mapping between any identifying symbol and the relevant code that it refers to.


### TODO
- Fix storage structute of `Scope`.
- Add rename function, datatype, variable capability.
- Add incremental parsing.
- Return code hints in response to parsing failures.
- Second pass for linting.
- Second pass for type inference.