"""
    getorcreate!(model::ModelInterface, context::Context, options::NodeCreationOptions, name, index)

Get or create a variable (name) from a factor graph model and context, using an index if provided.

This function searches for a variable (name) in the factor graph model and context specified by the arguments `model` and `context`. If the variable exists, 
it returns it. Otherwise, it creates a new variable and returns it.

# Arguments
- `model::FactorGraphModelInterface`: The factor graph model to search for or create the variable in.
- `context::Context`: The context to search for or create the variable in.
- `options::NodeCreationOptions`: Options for creating the variable. Must be a `NodeCreationOptions` object.
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
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, index::Nothing)

Get or create an individual (non-indexed) variable with the given name and options.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `options::NodeCreationOptions`: Options for node creation
- `name::Symbol`: Variable name
- `index::Nothing`: Indicates this is an individual variable (not indexed)

# Returns
The requested individual variable, either existing or newly created.

# Throws
- Error if a vector or tensor variable with the same name already exists
"""
function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index::Nothing)
    throw_if_vector_variable(context, name)
    throw_if_tensor_variable(context, name)
    return get(() -> add_variable_node!(model, context, name), get_individual_variables(context), name)
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, index::Integer)

Get or create a vector variable (1D indexed) with the given name, index, and options.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `options::NodeCreationOptions`: Options for node creation
- `name::Symbol`: Variable name
- `index::Integer`: Index for the variable in the vector

# Returns
The requested vector variable collection.

# Throws
- Error if an individual or tensor variable with the same name already exists
"""
function getorcreate!(
    model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, index::Integer
)
    throw_if_individual_variable(context, name)
    throw_if_tensor_variable(context, name)
    if !has_vector_variable(context, name)
        set_vector_variable!(context, name, ResizableArray(NodeLabel, Val(1)))
    end
    if !has_vector_variable(context, name, index)
        new_variable = add_variable_node!(model, context, options, name, index)
        set_vector_variable!(context, name, index, new_variable)
    end
    return get_vector_variable(context, name)
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, i1::Integer, is::Vararg{Integer})

Get or create a tensor variable (multi-dimensional indexed) with the given name, indices, and options.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `options::NodeCreationOptions`: Options for node creation
- `name::Symbol`: Variable name
- `i1::Integer`: First index
- `is::Vararg{Integer}`: Remaining indices

# Returns
The requested tensor variable collection.

# Throws
- Error if an individual or vector variable with the same name already exists
"""
function getorcreate!(
    model::FactorGraphModelInterface,
    context::ContextInterface,
    options::NodeCreationOptions,
    name::Symbol,
    i1::Integer,
    is::Vararg{Integer}
)
    throw_if_individual_variable(context, name)
    throw_if_vector_variable(context, name)
    if !has_tensor_variable(context, name)
        set_tensor_variable!(context, name, ResizableArray(NodeLabel, Val(1 + length(is))))
    end
    indices = (i1, is...)
    if !has_tensor_variable(context, name, indices)
        new_variable = add_variable_node!(model, context, options, name, indices)
        set_tensor_variable!(context, name, indices, new_variable)
    end
    return get_tensor_variable(context, name)
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, range::AbstractRange)

Get or create multiple vector variables for each index in the provided range.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `options::NodeCreationOptions`: Options for node creation
- `name::Symbol`: Variable name
- `range::AbstractRange`: Range of indices to create variables for

# Returns
The first variable in the created range (representing the collection).

# Throws
- Error if the range is empty
"""
function getorcreate!(
    model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, range::AbstractRange
)
    isempty(range) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(range) do i
        getorcreate!(model, context, options, name, i)
    end
    return getorcreate!(model, context, options, name, first(range))
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, r1::AbstractRange, rs::Vararg{AbstractRange})

Get or create multiple tensor variables for each combination of indices in the provided ranges.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `options::NodeCreationOptions`: Options for node creation
- `name::Symbol`: Variable name
- `r1::AbstractRange`: First range of indices
- `rs::Vararg{AbstractRange}`: Remaining ranges of indices

# Returns
The first variable in the created tensor (representing the collection).

# Throws
- Error if any of the ranges are empty
"""
function getorcreate!(
    model::FactorGraphModelInterface,
    context::ContextInterface,
    options::NodeCreationOptions,
    name::Symbol,
    r1::AbstractRange,
    rs::Vararg{AbstractRange}
)
    (isempty(r1) || any(isempty, rs)) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(Iterators.product(r1, rs...)) do i
        getorcreate!(model, context, options, name, i...)
    end
    return getorcreate!(model, context, options, name, first(r1), first.(rs)...)
end

"""
    getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, indices...)

Fallback method for getorcreate! that handles non-standard indices. Checks if the key is in the context, otherwise throws.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `options::NodeCreationOptions`: Options for node creation
- `name::Symbol`: Variable name
- `indices...`: Variable indices (any type)

# Returns
The existing variable if found in the context.

# Throws
- Error if the variable doesn't exist and cannot be created with the given indices
"""
function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, options::NodeCreationOptions, name::Symbol, indices...)
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
    add_variable_node!(model, context, NodeCreationOptions(value = var, kind = :constant), gensym(constvar))

"""
    add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index)

Add a variable node to the model with the given `name` and `index`.
This function is unsafe (doesn't check if a variable with the given name already exists in the model). 

# Arguments
- `model::FactorGraphModelInterface`: The model to which the node is added.
- `context::ContextInterface`: The context to which the symbol is added.
- `name::Symbol`: The ID of the variable.
- `index`: The index of the variable.

# Returns
- The generated label for the variable.
"""
function add_variable_node! end

"""
    add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface,, name::Symbol, index::Int)

Add a vector variable node to the model and store it in the context.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name
- `index::Int`: Vector variable index

# Returns
The label for the created variable node.
"""
function add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index::Int)
    label = __add_variable_node!(model, context, name, index)
    set_vector_variable!(context, name, index, label)
    return label
end

"""
    add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, indices::Vararg{Int})

Add a tensor variable node to the model and store it in the context.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name
- `indices::Vararg{Int}`: Tensor variable indices

# Returns
The label for the created variable node.
"""
function add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, indices::Vararg{Int})
    label = __add_variable_node!(model, context, name, indices)
    set_tensor_variable!(context, name, indices, label)
    return label
end

"""
    add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol)

Add a non-indexed variable node to the model and store it in the context.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface
- `name::Symbol`: Variable name

# Returns
The label for the created variable node.
"""
function add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol)
    label = __add_variable_node!(model, context, name, nothing)
    # Generate a unique symbol based on the name to avoid name collisions
    set_individual_variable!(context, gensym(name), label)
    return label
end

"""
    __add_variable_node!(model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index)

Internal helper to add a variable node to the model. Processes options through plugins and creates the actual node.

# Arguments
- `model::FactorGraphModelInterface`: The model interface
- `context::ContextInterface`: The context interface  
- `name::Symbol`: Variable name
- `index`: Variable index or `nothing`

# Returns
The label for the created variable node.
"""
function __add_variable_node!(
    model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index, kind, link, value; kwargs...
)
    # Create the potential node data from the variable properties
    potential_nodedata = create_variable_data(model, context, name, index, kind, link, value, kwargs)
    # Allow plugins to preprocess the node data before adding it to the model
    nodedata = preprocess_plugins(UnionPluginType(VariableNodePlugin(), FactorAndVariableNodesPlugin()), model, context, potential_nodedata)
    # Add the variable to the model and get its label
    label = add_variable!(model, nodedata)
    return label
end