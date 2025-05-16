"""
    ContextInterface

Abstract interface for a context in a probabilistic graphical model.
Contains information about a model or submodel's variables, factors, and structure.
"""
abstract type ContextInterface end

# Basic Properties
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

Set the return value of this context.
"""
function set_returnval!(context::C, value) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_returnval!, C, ContextInterface))
end

"""
    get_path_to_root(context::C) where {C<:ContextInterface}

Get the path from this context to the root context.
"""
function get_path_to_root(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_path_to_root, C, ContextInterface))
end

# Variable Access - Specific Types

"""
    get_individual_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Get an individual variable by name.
"""
function get_individual_variable(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_individual_variable, C, ContextInterface))
end

"""
    get_vector_variable(context::C, name::Symbol, index::Int) where {C<:ContextInterface}
    
Get a vector variable element by name and index.
"""
function get_vector_variable(context::C, name::Symbol, index::Int) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_vector_variable, C, ContextInterface))
end

"""
    get_tensor_variable(context::C, name::Symbol, indices::Tuple) where {C<:ContextInterface}
    
Get a tensor variable element by name and indices.
"""
function get_tensor_variable(context::C, name::Symbol, indices::Tuple) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_tensor_variable, C, ContextInterface))
end

"""
    get_proxy(context::C, name::Symbol) where {C<:ContextInterface}
    
Get a proxy by name.
"""
function get_proxy(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_proxy, C, ContextInterface))
end

"""
    get_factor_node(context::C, fform, identifier) where {C<:ContextInterface}
    
Get a factor node by functional form and identifier.
"""
function get_factor_node(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_node, C, ContextInterface))
end

"""
    get_child_context(context::C, fform, identifier) where {C<:ContextInterface}
    
Get a child context by functional form and identifier.
"""
function get_child_context(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_child_context, C, ContextInterface))
end

# Has Key Checks

"""
    has_individual_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Check if an individual variable with the given name exists.
"""
function has_individual_variable(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_individual_variable, C, ContextInterface))
end

"""
    has_vector_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Check if a vector variable with the given name exists.
"""
function has_vector_variable(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_vector_variable, C, ContextInterface))
end

"""
    has_vector_variable(context::C, name::Symbol, index::Int) where {C<:ContextInterface}
    
Check if a vector variable with the given name and index exists.
"""
function has_vector_variable(context::C, name::Symbol, index::Int) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_vector_variable, C, ContextInterface))
end

"""
    has_tensor_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Check if a tensor variable with the given name exists.
"""
function has_tensor_variable(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_tensor_variable, C, ContextInterface))
end

"""
    has_tensor_variable(context::C, name::Symbol, indices::Tuple) where {C<:ContextInterface}
    
Check if a tensor variable with the given name and indices exists.
"""
function has_tensor_variable(context::C, name::Symbol, indices::Tuple) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_tensor_variable, C, ContextInterface))
end

"""
    has_proxy(context::C, name::Symbol) where {C<:ContextInterface}
    
Check if a proxy with the given name exists.
"""
function has_proxy(context::C, name::Symbol) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_proxy, C, ContextInterface))
end

"""
    has_factor_node(context::C, fform, identifier) where {C<:ContextInterface}
    
Check if a factor node with the given functional form and identifier exists.
"""
function has_factor_node(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_factor_node, C, ContextInterface))
end

"""
    has_child_context(context::C, fform, identifier) where {C<:ContextInterface}
    
Check if a child context with the given functional form and identifier exists.
"""
function has_child_context(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_child_context, C, ContextInterface))
end

"""
    has_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Check if a variable with the given name exists in any form (individual, vector, tensor, proxy).
"""
function has_variable(context::C, name::Symbol) where {C <: ContextInterface}
    return has_individual_variable(context, name) ||
           has_vector_variable(context, name) ||
           has_tensor_variable(context, name) ||
           has_proxy(context, name)
end

# Setters for Variables and Nodes

"""
    set_individual_variable!(context::C, name::Symbol, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set an individual variable.
"""
function set_individual_variable!(context::C, name::Symbol, value::NodeLabelInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_individual_variable!, C, ContextInterface))
end

"""
    set_vector_variable!(context::C, name::Symbol, value::AbstractVector{NodeLabelInterface}) where {C<:ContextInterface}
    
Set a vector variable.
"""
function set_vector_variable!(context::C, name::Symbol, value::AbstractVector{NodeLabelInterface}) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_vector_variable!, C, ContextInterface))
end

"""
    set_vector_variable!(context::C, name::Symbol, index::Int, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set a vector variable element.
"""
function set_vector_variable!(context::C, name::Symbol, index::Int, value::NodeLabelInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_vector_variable!, C, ContextInterface))
end

"""
    set_tensor_variable!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface}) where {C<:ContextInterface}
    
Set a tensor variable.
"""
function set_tensor_variable!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface}) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_tensor_variable!, C, ContextInterface))
end

"""
    set_tensor_variable!(context::C, name::Symbol, indices::Tuple, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set a tensor variable element.
"""
function set_tensor_variable!(context::C, name::Symbol, indices::Tuple, value::NodeLabelInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_tensor_variable!, C, ContextInterface))
end

"""
    set_vector_variable_array!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface}) where {C<:ContextInterface}
    
Set an entire vector variable array.
"""
function set_vector_variable_array!(context::C, name::Symbol, value::AbstractVector{<:NodeLabelInterface}) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_vector_variable_array!, C, ContextInterface))
end

"""
    set_tensor_variable_array!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface}) where {C<:ContextInterface}
    
Set an entire tensor variable array.
"""
function set_tensor_variable_array!(context::C, name::Symbol, value::AbstractArray{<:NodeLabelInterface}) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_tensor_variable_array!, C, ContextInterface))
end

"""
    set_proxy!(context::C, name::Symbol, value::ProxyLabelInterface) where {C<:ContextInterface}
    
Set a proxy variable.
"""
function set_proxy!(context::C, name::Symbol, value::ProxyLabelInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_proxy!, C, ContextInterface))
end

"""
    set_factor_node!(context::C, fform, identifier, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set a factor node.
"""
function set_factor_node!(context::C, fform, identifier, value::NodeLabelInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_factor_node!, C, ContextInterface))
end

"""
    set_child_context!(context::C, fform, identifier, value::ContextInterface) where {C<:ContextInterface}
    
Set a child context.
"""
function set_child_context!(context::C, fform, identifier, value::ContextInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_child_context!, C, ContextInterface))
end

# Generalized accessors

"""
    get_variable(context::C, name::Symbol) where {C<:ContextInterface}
    
Get a variable by name, automatically determining if it's individual, vector, tensor, or proxy.
If the variable is a vector or tensor, returns the entire array.
"""
function get_variable(context::C, name::Symbol) where {C <: ContextInterface}
    if has_individual_variable(context, name)
        return get_individual_variable(context, name)
    elseif has_vector_variable(context, name)
        return get_vector_variable(context, name)
    elseif has_tensor_variable(context, name)
        return get_tensor_variable(context, name)
    elseif has_proxy(context, name)
        return get_proxy(context, name)
    end
    throw(KeyError(name))
end

"""
    get_variable(context::C, name::Symbol, index::Int) where {C<:ContextInterface}
    
Get an indexed element of a vector variable.
"""
function get_variable(context::C, name::Symbol, index::Int) where {C <: ContextInterface}
    if has_vector_variable(context, name)
        return get_vector_variable(context, name, index)
    end
    throw(ArgumentError("Variable $name is not a vector variable or doesn't exist"))
end

"""
    get_variable(context::C, name::Symbol, indices::Tuple) where {C<:ContextInterface}
    
Get an indexed element of a tensor variable.
"""
function get_variable(context::C, name::Symbol, indices::Tuple) where {C <: ContextInterface}
    if has_tensor_variable(context, name)
        return get_tensor_variable(context, name, indices)
    end
    throw(ArgumentError("Variable $name is not a tensor variable or doesn't exist"))
end

"""
    get_node(context::C, fform, identifier) where {C<:ContextInterface}
    
Get either a factor node or child context by functional form and identifier, 
automatically determining which type.
"""
function get_node(context::C, fform, identifier) where {C <: ContextInterface}
    if has_factor_node(context, fform, identifier)
        return get_factor_node(context, fform, identifier)
    elseif has_child_context(context, fform, identifier)
        return get_child_context(context, fform, identifier)
    end
    throw(KeyError("No node found for $fform with identifier $identifier"))
end

"""
    set_variable!(context::C, name::Symbol, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set an individual variable value.
"""
function set_variable!(context::C, name::Symbol, value::NodeLabelInterface) where {C <: ContextInterface}
    return set_individual_variable!(context, name, value)
end

"""
    set_variable!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface}) where {C<:ContextInterface}
    
Set a vector or tensor variable array, determined by the dimensionality of the array.
"""
function set_variable!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface, 1}) where {C <: ContextInterface, V}
    return set_vector_variable_array!(context, name, value)
end

function set_variable!(context::C, name::Symbol, value::AbstractArray{NodeLabelInterface}) where {C <: ContextInterface}
    return set_tensor_variable_array!(context, name, value)
end

"""
    set_variable!(context::C, name::Symbol, value::ProxyLabelInterface) where {C<:ContextInterface}
    
Set a proxy variable.
"""
function set_variable!(context::C, name::Symbol, value::ProxyLabelInterface) where {C <: ContextInterface}
    return set_proxy!(context, name, value)
end

"""
    set_variable!(context::C, name::Symbol, index::Int, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set an indexed element of a vector variable.
"""
function set_variable!(context::C, name::Symbol, index::Int, value::NodeLabelInterface) where {C <: ContextInterface}
    return set_vector_variable!(context, name, index, value)
end

"""
    set_variable!(context::C, name::Symbol, indices::Tuple, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set an indexed element of a tensor variable.
"""
function set_variable!(context::C, name::Symbol, indices::Tuple, value::NodeLabelInterface) where {C <: ContextInterface}
    return set_tensor_variable!(context, name, indices, value)
end

"""
    set_node!(context::C, fform, identifier, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set a factor node.
"""
function set_node!(context::C, fform, identifier, value::NodeLabelInterface) where {C <: ContextInterface}
    return set_factor_node!(context, fform, identifier, value)
end

"""
    set_node!(context::C, fform, identifier, value::ContextInterface) where {C<:ContextInterface}
    
Set a child context.
"""
function set_node!(context::C, fform, identifier, value::ContextInterface) where {C <: ContextInterface}
    return set_child_context!(context, fform, identifier, value)
end

# Collection accessors

"""
    get_individual_variables(context::C) where {C<:ContextInterface}
    
Get all individual variables in this context.
"""
function get_individual_variables(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_individual_variables, C, ContextInterface))
end

"""
    get_vector_variables(context::C) where {C<:ContextInterface}
    
Get all vector variables in this context.
"""
function get_vector_variables(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_vector_variables, C, ContextInterface))
end

"""
    get_tensor_variables(context::C) where {C<:ContextInterface}
    
Get all tensor variables in this context.
"""
function get_tensor_variables(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_tensor_variables, C, ContextInterface))
end

"""
    get_proxies(context::C) where {C<:ContextInterface}
    
Get all proxies in this context.
"""
function get_proxies(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_proxies, C, ContextInterface))
end

"""
    get_factor_nodes(context::C) where {C<:ContextInterface}
    
Get all factor nodes in this context.
"""
function get_factor_nodes(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_nodes, C, ContextInterface))
end

"""
    get_children(context::C) where {C<:ContextInterface}
    
Get all child contexts.
"""
function get_children(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_children, C, ContextInterface))
end

"""
    copy_markov_blanket_to_child!(child_context::C, interfaces::NamedTuple) where {C<:ContextInterface}
    
Copy interface variables from parent to child context.
"""
function copy_markov_blanket_to_child!(child_context::C, interfaces::NamedTuple) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(copy_markov_blanket_to_child!, C, ContextInterface))
end

"""
    Base.show(io::IO, mime::MIME"text/plain", context::C) where {C<:ContextInterface}

Display a string representation of the context.
"""
function Base.show(io::IO, mime::MIME"text/plain", context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(show, C, ContextInterface))
end
