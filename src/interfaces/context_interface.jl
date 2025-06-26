"""
    ContextInterface

Abstract interface for a context in a probabilistic graphical model.
Contains information about a model or submodel's variables, factors, and structure.
"""
abstract type ContextInterface end

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
The child context, when created, should be accessible via [`get_children`](@ref).
"""
function create_child_context(parent::C, functional_form::F, markov_blanket::NamedTuple) where {C <: ContextInterface, F}
    throw(GraphPPLInterfaceNotImplemented(create_child_context, C, ContextInterface))
end

"""
    has_children(context::C, functional_form::F) where {C <: ContextInterface, F}
    has_children(context::C, functional_form::F, index) where {C <: ContextInterface, F}

Check if the context has any children with the given functional form.
If `index` is provided, check if a child with that index exists.
"""
function has_children(context::C, functional_form::F, index = nothing) where {C <: ContextInterface, F}
    throw(GraphPPLInterfaceNotImplemented(has_children, C, ContextInterface))
end

"""
    get_children(context::C, functional_form::F, index = nothing) where {C <: ContextInterface, F}

Get the children of the context with the given functional form.
Does not check if the children exist. Use [`has_children`](@ref) to check if children of the given functional form exist.
If `index` is provided, get the child with that index. 
"""
function get_children(context::C, functional_form::F, index = nothing) where {C <: ContextInterface, F}
    throw(GraphPPLInterfaceNotImplemented(get_children, C, ContextInterface))
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

Get the return value of this context. If not set, should return `nothing`.
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
    return map(Base.Fix1(postprocess_returnval, context), value)
end

"""
    get_path_to_root(context::C) where {C<:ContextInterface}

Get the path from this context to the root context. The path is an iterable of contexts, starting with this context and ending with the root context.
"""
function get_path_to_root(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_path_to_root, C, ContextInterface))
end

"""
    get_variable(context::C, name::Symbol, index::Index) where {C<:ContextInterface}

Get a single variable by name and `index`. Does not check if the variable exists.
Use [`has_variable`](@ref) to check if a variable exists. 

!!! note
    This function always returns a single variable.
    To retrieve a collection of variables, which matches the given `index`, use [`get_collection_of_variables`](@ref).
"""
function get_variable(context::C, name::Symbol, index::Index) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable, C, ContextInterface))
end

"""
    get_variable_or_collection(context::C, name::Symbol, index_or_dimensionality::Union{Index, StaticInt}) where {C<:ContextInterface}

Get a collection of variables by name, which matches the given `index`. 
If the index has dimensionality 0, the function will return a single variable and is equivalent to [`get_variable`](@ref).
The actual content of the `index` is not important, only the dimensionality of the index is used.
Use [`get_variable`](@ref) to retrieve a single variable.
Instead of `index`, you can also provide a `StaticInt` of the dimensionality of the index.

Use [`has_variable_or_collection`](@ref) to check if a collection of variables exists.
"""
function get_variable_or_collection(context::C, name::Symbol, index::Index) where {C <: ContextInterface}
    return get_variable_or_collection(context, name, get_index_dimensionality(index))
end

function get_variable_or_collection(context::C, name::Symbol, dimensionality::StaticInt) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable_or_collection, C, ContextInterface))
end

"""
    has_variable(context::C, name::Symbol, index::Index) where {C<:ContextInterface}

Check if a variable with the given name and `index` exists in the context.
Use [`get_variable`](@ref) to retrieve a variable.

!!! note
    This function always check if a single variable exists. 
    For example a collection of variables may exist, but a particular variable with the given name index may not be defined yet.
    To check if a collection of variables exists, use [`has_variable_or_collection`](@ref).
"""
function has_variable(context::C, name::Symbol, index::Index) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_variable, C, ContextInterface))
end

"""
    has_variable_or_collection(context::C, name::Symbol, index_or_dimensionality::Union{Index, StaticInt}) where {C<:ContextInterface}

Check if a variable with the given name and `index` exists in the context.
If the index has dimensionality 0, the function checks if a single variable exists and is equivalent to [`has_variable`](@ref).
The actual content of the `index` is not important, only the dimensionality of the index is used.
Use [`has_variable`](@ref) to check if a single variable exists.
Instead of `index`, you can also provide a `StaticInt` of the dimensionality of the index.

Use [`get_variable_or_collection`](@ref) to retrieve a variable or a collection of variables.
"""
function has_variable_or_collection(context::C, name::Symbol, index::Index) where {C <: ContextInterface}
    return has_variable_or_collection(context, name, get_index_dimensionality(index))
end

function has_variable_or_collection(context::C, name::Symbol, dimensionality::StaticInt) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_variable_or_collection, C, ContextInterface))
end

"""
    set_variable!(context::C, variable_or_collection, name::Symbol, index::Index) where {C<:ContextInterface}
    
Set a variable in the context at the specified index. 
The variable typically will be a [`VariableNodeLabel`](@ref), but can also be a [`ProxyLabel`](@ref) or a [`VariableRef`](@ref).
"""
function set_variable!(context::C, variable_or_collection, name::Symbol, index::Index) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_variable!, C, ContextInterface))
end

"""
    get_factor(context::C, functional_form) where {C<:ContextInterface}
    get_factor(context::C, functional_form, index) where {C<:ContextInterface}

Get a collection of factors by its `functional_form`. Does not check if the factor exists.
Use [`has_factor`](@ref) to check if a factor exists. If `index` is provided, return a single factor.
"""
function get_factor(context::C, functional_form, index = nothing) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor, C, ContextInterface))
end

"""
    has_factor(context::C, functional_form) where {C<:ContextInterface}
    has_factor(context::C, functional_form, index) where {C<:ContextInterface}

Check if a factor with the given `functional_form` exists in the context.
Use [`get_factor`](@ref) to retrieve a factor. If `index` is provided, check if a factor with that index exists.
"""
function has_factor(context::C, functional_form, index = nothing) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_factor, C, ContextInterface))
end

"""
    set_factor!(context::C, factor, functional_form) where {C<:ContextInterface}
    
Set a factor. The factor typically will be a [`FactorNodeLabel`](@ref). Returns the index of the inserted factor within the context.
"""
function set_factor!(context::C, factor, functional_form) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_factor!, C, ContextInterface))
end