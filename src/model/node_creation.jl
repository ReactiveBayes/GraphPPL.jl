"""
    NodeCreationOptions(namedtuple)

Options for creating a node in a probabilistic graphical model. These are typically coming from the `where {}` block 
in the `@model` macro, but can also be created manually. Expects a `NamedTuple` as an input.
"""
struct NodeCreationOptions{N}
    options::N
end

const EmptyNodeCreationOptions = NodeCreationOptions{Nothing}(nothing)

NodeCreationOptions(; kwargs...) = convert(NodeCreationOptions, kwargs)

Base.convert(::Type{NodeCreationOptions}, ::@Kwargs{}) = NodeCreationOptions(nothing)
Base.convert(::Type{NodeCreationOptions}, options) = NodeCreationOptions(NamedTuple(options))

Base.haskey(options::NodeCreationOptions, key::Symbol) = haskey(options.options, key)
Base.getindex(options::NodeCreationOptions, keys...) = getindex(options.options, keys...)
Base.getindex(options::NodeCreationOptions, keys::NTuple{N, Symbol}) where {N} = NodeCreationOptions(getindex(options.options, keys))
Base.keys(options::NodeCreationOptions) = keys(options.options)
Base.get(options::NodeCreationOptions, key::Symbol, default) = get(options.options, key, default)

# Fast fallback for empty options
Base.haskey(::NodeCreationOptions{Nothing}, key::Symbol) = false
Base.getindex(::NodeCreationOptions{Nothing}, keys...) = error("type `NodeCreationOptions{Nothing}` has no field $(keys)")
Base.keys(::NodeCreationOptions{Nothing}) = ()
Base.get(::NodeCreationOptions{Nothing}, key::Symbol, default) = default

withopts(::NodeCreationOptions{Nothing}, options::NamedTuple) = NodeCreationOptions(options)
withopts(options::NodeCreationOptions, extra::NamedTuple) = NodeCreationOptions((; options.options..., extra...))

withoutopts(::NodeCreationOptions{Nothing}, ::Val) = NodeCreationOptions(nothing)

function withoutopts(options::NodeCreationOptions, ::Val{K}) where {K}
    newoptions = options.options[filter(key -> key ∉ K, keys(options.options))]
    # Should be compiled out, there are tests for it
    if isempty(newoptions)
        return NodeCreationOptions(nothing)
    else
        return NodeCreationOptions(newoptions)
    end
end

"""
    getorcreate!(model::AbstractModel, context::Context, options::NodeCreationOptions, name, index)

Get or create a variable (name) from a factor graph model and context, using an index if provided.

This function searches for a variable (name) in the factor graph model and context specified by the arguments `model` and `context`. If the variable exists, 
it returns it. Otherwise, it creates a new variable and returns it.

# Arguments
- `model::AbstractModel`: The factor graph model to search for or create the variable in.
- `context::Context`: The context to search for or create the variable in.
- `options::NodeCreationOptions`: Options for creating the variable. Must be a `NodeCreationOptions` object.
- `name`: The variable (name) to search for or create. Must be a symbol.
- `index`: Optional index for the variable. Can be an integer, a collection of integers, or `nothing`. If the index is `nothing` creates a single variable. 
If the index is an integer creates a vector-like variable. If the index is a collection of integers creates a tensor-like variable.

# Returns
The variable (name) found or created in the factor graph model and context.
"""
function getorcreate! end

getorcreate!(::AbstractModel, ::Context, name::Symbol) = error("Index is required in the `getorcreate!` function for variable `$(name)`")
getorcreate!(::AbstractModel, ::Context, options::NodeCreationOptions, name::Symbol) =
    error("Index is required in the `getorcreate!` function for variable `$(name)`")

function getorcreate!(model::AbstractModel, ctx::Context, name::Symbol, index...)
    return getorcreate!(model, ctx, EmptyNodeCreationOptions, name, index...)
end

function getorcreate!(model::AbstractModel, ctx::Context, options::NodeCreationOptions, name::Symbol, index::Nothing)
    throw_if_vector_variable(ctx, name)
    throw_if_tensor_variable(ctx, name)
    return get(() -> add_variable_node!(model, ctx, options, name, index), ctx.individual_variables, name)
end

function getorcreate!(model::AbstractModel, ctx::Context, options::NodeCreationOptions, name::Symbol, index::Integer)
    throw_if_individual_variable(ctx, name)
    throw_if_tensor_variable(ctx, name)
    if !haskey(ctx.vector_variables, name)
        ctx[name] = ResizableArray(NodeLabel, Val(1))
    end
    vectorvar = ctx.vector_variables[name]
    if !isassigned(vectorvar, index)
        vectorvar[index] = add_variable_node!(model, ctx, options, name, index)
    end
    return vectorvar
end

function getorcreate!(model::AbstractModel, ctx::Context, options::NodeCreationOptions, name::Symbol, i1::Integer, is::Vararg{Integer})
    throw_if_individual_variable(ctx, name)
    throw_if_vector_variable(ctx, name)
    if !haskey(ctx.tensor_variables, name)
        ctx[name] = ResizableArray(NodeLabel, Val(1 + length(is)))
    end
    tensorvar = ctx.tensor_variables[name]
    if !isassigned(tensorvar, i1, is...)
        tensorvar[i1, is...] = add_variable_node!(model, ctx, options, name, (i1, is...))
    end
    return tensorvar
end

function getorcreate!(model::AbstractModel, ctx::Context, options::NodeCreationOptions, name::Symbol, range::AbstractRange)
    isempty(range) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(range) do i
        getorcreate!(model, ctx, options, name, i)
    end
    return getorcreate!(model, ctx, options, name, first(range))
end

function getorcreate!(
    model::AbstractModel, ctx::Context, options::NodeCreationOptions, name::Symbol, r1::AbstractRange, rs::Vararg{AbstractRange}
)
    (isempty(r1) || any(isempty, rs)) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(Iterators.product(r1, rs...)) do i
        getorcreate!(model, ctx, options, name, i...)
    end
    return getorcreate!(model, ctx, options, name, first(r1), first.(rs)...)
end

function getorcreate!(model::AbstractModel, ctx::Context, options::NodeCreationOptions, name::Symbol, indices...)
    if haskey(ctx, name)
        var = ctx[name]
        return var
    end
    error(lazy"Cannot create a variable named `$(name)` with non-standard indices $(indices)")
end

getifcreated(model::AbstractModel, context::Context, var::NodeLabel) = var
getifcreated(model::AbstractModel, context::Context, var::ResizableArray) = var
getifcreated(
    model::AbstractModel,
    context::Context,
    var::Union{Tuple, AbstractArray{T}} where {T <: Union{NodeLabel, ProxyLabel, <:AbstractVariableReference}}
) = map((v) -> getifcreated(model, context, v), var)
getifcreated(model::AbstractModel, context::Context, var::ProxyLabel) = var
getifcreated(model::AbstractModel, context::Context, var) =
    add_constant_node!(model, context, NodeCreationOptions(value = var, kind = :constant), :constvar, nothing)

"""
    add_variable_node!(model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index)

Add a variable node to the model with the given `name` and `index`.
This function is unsafe (doesn't check if a variable with the given name already exists in the model). 

Args:
    - `model::AbstractModel`: The model to which the node is added.
    - `context::Context`: The context to which the symbol is added.
    - `options::NodeCreationOptions`: The options for the creation process.
    - `name::Symbol`: The ID of the variable.
    - `index`: The index of the variable.

Returns:
    - The generated symbol for the variable.
"""
function add_variable_node! end

function add_variable_node!(model::AbstractModel, context::Context, name::Symbol, index)
    return add_variable_node!(model, context, EmptyNodeCreationOptions, name, index)
end

function add_variable_node!(model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index)
    label = __add_variable_node!(model, context, options, name, index)
    context[name, index] = label
end

function add_constant_node!(model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index)
    label = __add_variable_node!(model, context, options, name, index)
    context[to_symbol(name, label.global_counter), index] = label   # to_symbol(label) is type unstable and we know the type of label.name here from name
    return label
end

function __add_variable_node!(model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index)
    # In theory plugins are able to overwrite this
    potential_label = generate_nodelabel(model, name)
    potential_nodedata = NodeData(context, convert(VariableNodeProperties, name, index, options))
    label, nodedata = preprocess_plugins(
        UnionPluginType(VariableNodePlugin(), FactorAndVariableNodesPlugin()), model, context, potential_label, potential_nodedata, options
    )
    add_vertex!(model, label, nodedata)
    return label
end

"""
    generate_nodelabel(model::AbstractModel, name::Symbol)

Generate a new `NodeLabel` object with a unique identifier based on the specified name and the
number of nodes already in the model.

Arguments:
- `model`: A `AbstractModel` object representing the probabilistic graphical model.
- `name`: A symbol representing the name of the node.
- `variable_type`: A UInt8 representing the type of the variable. 0 = factor, 1 = individual variable, 2 = vector variable, 3 = tensor variable
- `index`: An integer or tuple of integers representing the index of the variable.
"""
function generate_nodelabel(model::AbstractModel, name)
    nextcounter = setcounter!(model, getcounter(model) + 1)
    return NodeLabel(name, nextcounter)
end