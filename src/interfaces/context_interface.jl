"""
    ContextInterface

Abstract interface for a context in a probabilistic graphical model.
Contains information about a model or submodel's variables, factors, and structure.
"""
abstract type ContextInterface end

"""
    FactorID(fform, index)

A unique identifier for a single factor node or a submodel of type `fform` in an arbitrary `ContextInterface`.
A submodel can have multiple factor nodes of the same type, e.g. `Normal` factors.
The `index` is used to distinguish between them. 
The same applies to submodels which are created by the same functional form.
"""
struct FactorID{F}
    fform::F
    index::Int64
end

FactorID(::Type{F}, index) where {F} = FactorID{Type{F}}(F, index)
FactorID(fform, index) = FactorID(fform, index)

fform(id::FactorID) = id.fform
index(id::FactorID) = id.index

Base.show(io::IO, id::FactorID) = print(io, "(", fform(id), ", ", index(id), ")")
Base.:(==)(id1::FactorID{F}, id2::FactorID{T}) where {F, T} = id1.fform == id2.fform && id1.index == id2.index
Base.hash(id::FactorID, h::UInt) = hash(id.fform, hash(id.index, h))

"""
    create_root_context(::Type{C}) where {C <: ContextInterface}

Create a new context of type `C`. The root context always has `identity` as its functional form.
"""
function create_root_context(::Type{C}) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(create_root_context, C, ContextInterface))
end

"""
    create_child_context(parent::C, functional_form::F, markov_blanket::NamedTuple) where {C <: ContextInterface, F}

Create a new child context of type C with the given functional form and markov blanket.
The `markov_blanket` is a named tuple of `Symbol` => `ProxyLabel` pairs.
"""
function create_child_context(parent::C, functional_form::F, markov_blanket::NamedTuple) where {C <: ContextInterface, F}
    throw(GraphPPLInterfaceNotImplemented(create_child_context, C, ContextInterface))
end

"""
    get_depth(context::C) where {C<:ContextInterface}

Get the depth of the context in the model hierarchy.
"""
function get_depth(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_depth, C, ContextInterface))
end

"""
    get_functional_form(context::C) where {C<:ContextInterface}

Get the functional form (model function) associated with this context.
Returns `identity` for the root context.
"""
function get_functional_form(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_functional_form, C, ContextInterface))
end

"""
    get_prefix(context::C) where {C<:ContextInterface}

Get the prefix string used for naming entities in this context.
"""
function get_prefix(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_prefix, C, ContextInterface))
end

"""
    get_parent(context::C) where {C<:ContextInterface}

Get the parent context, or nothing if this is a root context.
"""
function get_parent(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_parent, C, ContextInterface))
end

"""
    get_short_name(context::C) where {C<:ContextInterface}

Get a short name identifier for the context.
"""
function get_short_name(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_short_name, C, ContextInterface))
end

"""
    get_returnval(context::C) where {C<:ContextInterface}

Get the return value of this context.
"""
function get_returnval(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_returnval, C, ContextInterface))
end

"""
    set_returnval!(context::C, value) where {C<:ContextInterface}

Set the return value of this context. Typically also calls [`postprocess_returnval`](@ref) to postprocess the value.
"""
function set_returnval!(context::C, value) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_returnval!, C, ContextInterface))
end

"""
    postprocess_returnval(context::C, value) where {C<:ContextInterface}
    postprocess_returnval(context::C, value::Tuple) where {C<:ContextInterface}

Postprocess the return value of this context. By default, return the value as is. 
For tuples, postprocess each element. Also has special behavior for [`ProxyLabel`](@ref)s and [`VariableRef`](@ref)s.
"""
function postprocess_returnval(context::ContextInterface, value)
    return value
end

function postprocess_returnval(context::ContextInterface, value::Tuple)
    return map(postprocess_returnval, value)
end

"""
    get_path_to_root(context::C) where {C<:ContextInterface}

Get the path from this context to the root context. The path is an iterable of contexts, starting with this context and ending with the root context.
"""
function get_path_to_root(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_path_to_root, C, ContextInterface))
end

"""
    get_variable(context::C, name::Symbol) where {C<:ContextInterface}

Get a variable (or a collection of variables) by name. Does not check if the variable exists.
Use [`has_variable`](@ref) to check if a variable exists.
"""
function get_variable(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable, C, ContextInterface))
end

"""
    get_factor(context::C, id::FactorID)

Get a factor by its id. Does not check if the factor exists.
Use [`has_factor`](@ref) to check if a factor exists.
"""
function get_factor(context::C, id::FactorID) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor, C, ContextInterface))
end

"""
    has_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Check if a variable (or a collection of variables) with the given name exists in the context.
Use [`get_variable`](@ref) to retrieve a variable.
"""
function has_variable(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_variable, C, ContextInterface))
end

"""
    has_factor(context::C, id::FactorID) where {C<:ContextInterface}

Check if a factor with the given id exists in the context.
Use [`get_factor`](@ref) to retrieve a factor.
"""
function has_factor(context::C, id::FactorID) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_factor, C, ContextInterface))
end

"""
    set_variable!(context::C, variable_or_collection, name::Symbol) where {C<:ContextInterface}
    set_variable!(context::C, variable_or_collection, name::Symbol, index) where {C<:ContextInterface}
    
Set a variable (or a collection of variables) in the context at the specified index. 
If index is specified, a single variable should be provided (not a collection).
The variable typically will be a [`VariableNodeLabel`](@ref), but can also be a [`ProxyLabel`](@ref) or a [`VariableRef`](@ref).
The collection typically will be a [`ResizableArray`](@ref).
"""
function set_variable!(context::C, variable_or_collection, name::Symbol, index = nothing) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_variable!, C, ContextInterface))
end

"""
    set_factor!(context::C, factor, id::FactorID) where {C<:ContextInterface}
    
Set a factor. The factor typically will be a [`FactorNodeLabel`](@ref).
"""
function set_factor!(context::C, factor, id::FactorID) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_factor!, C, ContextInterface))
end