"""
    getorcreate!(model::ModelInterface, context::Context, name, index)

Get or create a variable (name) from a factor graph model and context, using an index if provided.

This function searches for a variable (name) in the factor graph model and context specified by the arguments `model` and `context`. If the variable exists, 
it returns it. Otherwise, it creates a new variable and returns it.

# Arguments
- `model::FactorGraphModelInterface`: The factor graph model to search for or create the variable in.
- `context::Context`: The context to search for or create the variable in.
- `name`: The variable (name) to search for or create. Must be a symbol.
- `index`: Optional index for the variable. Can be an integer, a collection of integers, or `nothing`. If the index is `nothing` creates a single variable. 
If the index is an integer creates a vector-like variable. If the index is a collection of integers creates a tensor-like variable.

# Returns
The variable (name) found or created in the factor graph model and context.
"""
function getorcreate! end

getorcreate!(::FactorGraphModelInterface, ::ContextInterface, name::Symbol) =
    error("Index is required in the `getorcreate!` function for variable `$(name)`")

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface,  name::Symbol, index)

Get or create a variable with the given name.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name
- `index`: Variable index or `nothing`

# Returns
The requested individual variable, either existing or newly created.

# Throws
- Error if a vector or tensor variable with the same name already exists
"""
function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index)
    if has_variable(context, name, index)
        return get_variable(context, name, index)
    end
    add_variable_node!(model, context, name, index, VariableNodeKind.Random, nothing, nothing)
    return get_variable(context, name, nothing)
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, range::AbstractRange)

Get or create multiple vector variables for each index in the provided range.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name
- `range::AbstractRange`: Range of indices to create variables for

# Returns
The first variable in the created range (representing the collection).

# Throws
- Error if the range is empty
"""
function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, range::AbstractRange)
    isempty(range) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(range) do i
        getorcreate!(model, context, name, i)
    end
    return getorcreate!(model, context, name, first(range))
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface,  name::Symbol, r1::AbstractRange, rs::Vararg{AbstractRange})

Get or create multiple tensor variables for each combination of indices in the provided ranges.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name
- `r1::AbstractRange`: First range of indices
- `rs::Vararg{AbstractRange}`: Remaining ranges of indices

# Returns
The first variable in the created tensor (representing the collection).

# Throws
- Error if any of the ranges are empty
"""
function getorcreate!(
    model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, r1::AbstractRange, rs::Vararg{AbstractRange}
)
    (isempty(r1) || any(isempty, rs)) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(Iterators.product(r1, rs...)) do i
        getorcreate!(model, context, name, i...)
    end
    return getorcreate!(model, context, name, first(r1), first.(rs)...)
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface,  name::Symbol, indices...)

Fallback method for getorcreate! that handles non-standard indices. Checks if the key is in the context, otherwise throws.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name
- `indices...`: Variable indices (any type)

# Returns
The existing variable if found in the context.

# Throws
- Error if the variable doesn't exist and cannot be created with the given indices
"""
function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, indices...)
    if haskey(context, name)
        var = get_variable(context, name)
        return var
    end
    error(lazy"Cannot create a variable named `$(name)` with non-standard indices $(indices)")
end

"""
    getifcreated(model::FactorGraphModelInterface, context::ContextInterface, var)

Get a variable if it already exists as a node, or create a constant node if it's a raw value.
This function handles different variable types differently:
- `VariableNodeLabel`, `ProxyLabel`, `ResizableArray`: Returns as-is
- Collections of labels: Maps `getifcreated` over each element
- Any other value: Creates a new constant node

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `var`: The variable to process

# Returns
The variable node or nodes, either as-is or newly created.
"""
getifcreated(model::FactorGraphModelInterface, context::ContextInterface, var::VariableNodeLabel) = var
getifcreated(model::FactorGraphModelInterface, context::ContextInterface, var::ResizableArray) = var
getifcreated(model::FactorGraphModelInterface, context::ContextInterface, var::ProxyLabel) = var

getifcreated(
    model::FactorGraphModelInterface,
    context::ContextInterface,
    var::Union{Tuple, AbstractArray{T}} where {T <: Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef}}
) = map((v) -> getifcreated(model, context, v), var)
getifcreated(model::FactorGraphModelInterface, context::ContextInterface, var) =
    add_variable_node!(model, context, gensym(), nothing, VariableNodeKind.Constant, nothing, var)

"""
    add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index, kind, link, value)

Internal helper to add a variable node to the model. Processes through plugins and creates the actual node.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface  
- `name::Symbol`: Variable name
- `index`: Variable index or `nothing`

# Returns
The label for the created variable node.
"""
function add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index, kind, link, value)
    potential_nodedata = create_variable_data(model, name, index, kind, link, value)
    nodedata = preprocess_variable_node_plugins(model, context, potential_nodedata)
    label = add_variable!(model, nodedata)
    set_variable!(context, label, name, index)
    return label
end