module Syntax

abstract Expression 

abstract ShortForm
abstract LongForm


# Operators
type UnaryOpCall{op} <: Expression
    arg::Expression
end

type BinaryOpCall{op} <: Expression
    arg1::Expression
    arg2::Expression
end

type Assignment
    obj::Expression
    val::Expression
end

type Conditional
    cond::Expression
    ifblock::Expression
    elseblock::Expression
end

type OR
    arg1::Expression
    arg2::Expression
end

type AND
    arg1::Expression
    arg2::Expression
end

type Pipe{D}
    arg1::Expression
    arg2::Expression
end

type Declaration
    val::Expression
    typ::Expression
end

type Dot
    args::Vector{Expression}
end

type FunctionCall
    name::Identifier
    args::Vector{Expression}
end

type MacroCall{T}
    name::Identifier
    args::Vector{Expression}
end

type Block
    args::Vector{Expression}
end

type Tuple
    args::Vector{Expression}
end

type Ref
    arg::Expression
    ind::Expression
end

type Do
    func::FunctionCall
    arg::Expression
    body::Block
end

# Declarations

type FunctionDecl{T}
    sig::Expression
    body::Block
end

type MacroDecl{T}
    sig::Expression
    body::Block
end

abstract Mutable
abstract Immutable

type StructDecl{m}
    name::Identifier
    parameters::Vector{Expression}
    super::Expression
    fields::Vector{Expression}
    constructor::FunctionDecl
end

type AbstractDecl 
    name::Expression
    val::Expression
end

type BitsTypeDecl
    name::Expression
    val::Expression
end

# Control flow

type Break end
type Continue end

type If
    cond
    ifblock::Block
    elseblock::Block
end

type For
    range
    body::Block
end

type While
    cond
    body::Block
end

type Let
    args::Vector
    body::Block
end



# Prefixes
type Const
    arg::BinaryOpCall
end

type Const
    arg::Expression
end

type Local
    arg::Expression
end

type Return
    arg::Expression
end

# Modules

type Module{T}
    body::Block
end

type Import{T,R}
    mod::Expression
    arg::Expression
end

# Generators

type Generator{C} 
    typ
    range
    arg
end



end