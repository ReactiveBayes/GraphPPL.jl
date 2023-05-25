using Graphs
using MetaGraphsNext
import Base: put!, haskey, gensym, getindex, getproperty, setproperty!, setindex!
using GraphPlot, Compose
import Cairo

"""
The Model struct contains all information about the Factor Graph and contains a MetaGraph object and a counter. 
The counter is implemented because it allows for an efficient `gensym` implementation
"""
struct Model
    graph::MetaGraph
    counter::Base.RefValue{Int64}
end

"""
    NodeLabel(name::Symbol, index::Int64)

A structure representing a node in a probabilistic graphical model. It contains a symbol
representing the name of the node, an integer representing the unique identifier of the node,
a UInt8 representing the type of the variable, and an integer or tuple of integers representing
the index of the variable.
"""
struct NodeLabel
    name::Any
    index::Int64
end

name(label::NodeLabel) = label.name


struct VariableNodeData
    name::Symbol
    options::Union{Nothing,Dict,NamedTuple}
end

struct FactorNodeData
    fform::Any
    options::Union{Nothing,Dict,NamedTuple}
end

const NodeData = Union{FactorNodeData,VariableNodeData}

value(node::VariableNodeData) = node.options[:value]
node_options(node::NodeData) = node.options

struct EdgeLabel
    name::Symbol
    index::Val
end
EdgeLabel(name::Symbol, index::Int64) = EdgeLabel(name, Val(index))


""" 
    Model(graph::MetaGraph)

A structure representing a probabilistic graphical model. It contains a `MetaGraph` object
representing the factor graph and a `Base.RefValue{Int64}` object to keep track of the number
of nodes in the graph.

Fields:
- `graph`: A `MetaGraph` object representing the factor graph.
- `counter`: A `Base.RefValue{Int64}` object keeping track of the number of nodes in the graph.
"""
Model(graph::MetaGraph) = Model(graph, Base.RefValue(0))


Base.setindex!(model::Model, val::NodeData, key::NodeLabel) =
    Base.setindex!(model.graph, val, key)
Base.setindex!(model::Model, val::EdgeLabel, src::NodeLabel, dst::NodeLabel) =
    Base.setindex!(model.graph, val, src, dst)
Base.getindex(model::Model) = Base.getindex(model.graph)
Base.getindex(model::Model, key::NodeLabel) = Base.getindex(model.graph, key)
Base.getindex(model::Model, src::NodeLabel, dst::NodeLabel) =
    Base.getindex(model.graph, src, dst)


function Base.getproperty(val::Model, p::Symbol)
    if p === :counter
        return getfield(val, :counter)[]
    else
        return getfield(val, p)
    end
end

function Base.setproperty!(val::Model, p::Symbol, new_count)
    if p === :counter
        return getfield(val, :counter)[] = new_count
    else
        return setfield!(val, p, x)
    end
end

increase_count(model::Model) = Base.setproperty!(model, :counter, model.counter + 1)

Graphs.nv(model::Model) = Graphs.nv(model.graph)
Graphs.ne(model::Model) = Graphs.ne(model.graph)
Graphs.edges(model::Model) = collect(Graphs.edges(model.graph))
MetaGraphsNext.neighbors(model::Model, node::NodeLabel) =
    label_for.(
        (model.graph,),
        collect(MetaGraphsNext.neighbors(model.graph, code_for(model.graph, node))),
    )


function Graphs.edges(model::Model, node::NodeLabel)
    neighbors = MetaGraphsNext.neighbors(model, node)
    return [model.graph[node, neighbor] for neighbor in neighbors]
end



"""
    generate_nodelabel(model::Model, name::Symbol)

Generate a new `NodeLabel` object with a unique identifier based on the specified name and the
number of nodes already in the model.

Arguments:
- `model`: A `Model` object representing the probabilistic graphical model.
- `name`: A symbol representing the name of the node.
- `variable_type`: A UInt8 representing the type of the variable. 0 = factor, 1 = individual variable, 2 = vector variable, 3 = tensor variable
- `index`: An integer or tuple of integers representing the index of the variable.

Returns:
A new `NodeLabel` object with a unique identifier.
"""
function generate_nodelabel(model::Model, name)
    increase_count(model)
    return NodeLabel(name, model.counter)
end


function Base.gensym(model::Model, name::Symbol)
    increase_count
    return Symbol(String(name) * "_" * string(model.counter))
end

to_symbol(id::NodeLabel) = Symbol(String(Symbol(id.name)) * "_" * string(id.index))

struct Context
    depth::Int64
    prefix::String
    individual_variables::Dict{Symbol,NodeLabel}
    vector_variables::Dict{Symbol,ResizableArray{NodeLabel}}
    tensor_variables::Dict{Symbol,ResizableArray}
    factor_nodes::Dict{Symbol,Union{NodeLabel,Context}}
end

function Base.show(io::IO, context::Context)
    indentation = 2 * context.depth
    println(io, "$("    " ^ indentation)Context: $(context.prefix)")
    println(io, "$("    " ^ (indentation + 1))Individual variables:")
    for (variable_name, variable_label) in context.individual_variables
        println(
            io,
            "$("    " ^ (indentation + 2))$(variable_name): $(to_symbol(variable_label))",
        )
    end
    println(io, "$("    " ^ (indentation + 1))Vector variables:")
    for (variable_name, variable_labels) in context.vector_variables
        println(io, "$("    " ^ (indentation + 2))$(variable_name)")
    end
    println(io, "$("    " ^ (indentation + 1))Tensor variables: ")
    for (variable_name, variable_labels) in context.tensor_variables
        println(io, "$("    " ^ (indentation + 2))$(variable_name)")
    end
    println(io, "$("    " ^ (indentation + 1))Factor nodes: ")
    for (factor_label, factor_context) in context.factor_nodes
        if isa(factor_context, Context)
            println(io, "$("    " ^ (indentation + 2))$(factor_label) : ")
            show(io, factor_context)
        else
            println(
                io,
                "$("    " ^ (indentation + 2))$(factor_label) : $(to_symbol(factor_context))",
            )
        end
    end
end

name(f::Function) = String(Symbol(f))

Context(depth::Int, prefix::String) = Context(depth, prefix, Dict(), Dict(), Dict(), Dict())
Context(parent::Context, model_name::String) =
    Context(parent.depth + 1, parent.prefix * model_name * "_")
Context(parent::Context, model_name::Function) = Context(parent, name(model_name))
Context() = Context(0, "")

haskey(context::Context, key::Symbol) =
    haskey(context.individual_variables, key) ||
    haskey(context.vector_variables, key) ||
    haskey(context.tensor_variables, key) ||
    haskey(context.factor_nodes, key)

function Base.getindex(c::Context, key::Symbol)
    if haskey(c.individual_variables, key)
        return c.individual_variables[key]
    elseif haskey(c.vector_variables, key)
        return c.vector_variables[key]
    elseif haskey(c.tensor_variables, key)
        return c.tensor_variables[key]
    elseif haskey(c.factor_nodes, key)
        return c.factor_nodes[key]
    end
    throw(KeyError("Node " * String(key) * " not found in Context " * c.prefix))
end

function Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::Nothing)
    return c.individual_variables[key] = val
end

function Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::Int)
    return c.vector_variables[key][index] = val
end

function Base.setindex!(
    c::Context,
    val::NodeLabel,
    key::Symbol,
    index::NTuple{N,Int64},
) where {N}
    return c.tensor_variables[key][index...] = val
end



context(model::Model) = model.graph[]

abstract type NodeType end

struct Composite <: NodeType end
struct Atomic <: NodeType end


NodeType(::Type) = Atomic()
NodeType(::Function) = Atomic()

abstract type NodeBehaviour end

struct Stochastic <: NodeBehaviour end
struct Deterministic <: NodeBehaviour end

NodeBehaviour(x) = Deterministic()

"""
create_model()

Create a new empty probabilistic graphical model. 

Returns:
A `Model` object representing the probabilistic graphical model.
"""
function create_model()
    model = MetaGraph(
        Graph(),
        label_type = NodeLabel,
        vertex_data_type = NodeData,
        graph_data = Context(),
        edge_data_type = EdgeLabel,
    )
    model = Model(model)
    return model
end

"""
copy_markov_blanket_to_child_context(child_context::Context, interfaces::NamedTuple)

Copy the variables in the Markov blanket of a parent context to a child context, using a mapping specified by a named tuple.

The Markov blanket of a node or model in a Factor Graph is defined as the set of its outgoing interfaces. This function copies the variables in the Markov blanket of the parent context specified by the named tuple `interfaces` to the child context `child_context`, by setting each child variable in `child_context.individual_variables` to its corresponding parent variable in `interfaces`.

# Arguments
- `child_context::Context`: The child context to which to copy the Markov blanket variables.
- `interfaces::NamedTuple`: A named tuple that maps child variable names to parent variable names.
"""
function copy_markov_blanket_to_child_context(
    child_context::Context,
    interfaces::NamedTuple,
)
    for (name_in_child, object_in_parent) in iterator(interfaces)
        add_to_child_context(child_context, name_in_child, object_in_parent)
    end
end

add_to_child_context(
    child_context::Context,
    name_in_child::Symbol,
    object_in_parent::NodeLabel,
) = child_context.individual_variables[name_in_child] = object_in_parent
function add_to_child_context(
    child_context::Context,
    name_in_child::Symbol,
    object_in_parent::ResizableArray{NodeLabel},
)
    # Using if-statement here instead of dispatching is approx. 4x faster
    if length(size(object_in_parent)) == 1
        child_context.vector_variables[name_in_child] = object_in_parent
    else
        child_context.tensor_variables[name_in_child] = object_in_parent
    end
end
add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent) =
    nothing


check_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ?
    error("Variable $name is already an individual variable in the model") : nothing
check_if_vector_variable(context::Context, name::Symbol) =
    haskey(context.vector_variables, name) ?
    error("Variable $name is already a vector variable in the model") : nothing
check_if_tensor_variable(context::Context, name::Symbol) =
    haskey(context.tensor_variables, name) ?
    error("Variable $name is already a tensor variable in the model") : nothing

check_variate_compatability(node::NodeLabel, index::Nothing) = true
check_variate_compatability(node::NodeLabel, index) = error(
    "Cannot call single random variable on the left-hand-side by an indexed statement",
)

function check_variate_compatability(
    node::ResizableArray{NodeLabel,V,N},
    index...,
) where {V,N}
    if !(length(index) == N)
        error(
            "Index of length $(length(index)) not possible for $N-dimensional vector of random variables",
        )
    end

    return isassigned(node, index...)
end

check_variate_compatability(
    node::ResizableArray{NodeLabel,V,N},
    index::Nothing,
) where {V,N} = error(
    "Cannot call vector of random variables on the left-hand-side by an unindexed statement",
)


"""
    getorcreate!(model::Model, context::Context, edge, index)

Get or create a variable (edge) from a factor graph model and context, using an index if provided.

This function searches for a variable (edge) in the factor graph model and context specified by the arguments `model` and `context`. If the variable exists, it returns it. Otherwise, it creates a new variable and returns it.

# Arguments
- `model::Model`: The factor graph model to search for or create the variable in.
- `context::Context`: The context to search for or create the variable in.
- `edge`: The variable (edge) to search for or create. Can be a symbol, a tuple of symbols, or an array of symbols.
- `index`: Optional index for the variable. Can be an integer, a tuple of integers, or `nothing`.

# Returns
The variable (edge) found or created in the factor graph model and context.

# Examples
Suppose we have a factor graph model `model` and a context `context`. We can get or create a variable "x" in the context using the following code:
getorcreate!(model, context, :x)
"""
function getorcreate!(model::Model, ctx::Context, name::Symbol, index::Nothing)
    check_if_vector_variable(ctx, name)
    check_if_tensor_variable(ctx, name)
    return get(
        () -> add_variable_node!(model, ctx, name; index = nothing),
        ctx.individual_variables,
        name,
    )
end

getorcreate!(model::Model, ctx::Context, name::Symbol, index::AbstractArray{Int}) =
    getorcreate!(model, ctx, name, index...)

function getorcreate!(model::Model, ctx::Context, name::Symbol, index::Integer)
    check_if_individual_variable(ctx, name)
    check_if_tensor_variable(ctx, name)
    if !haskey(ctx.vector_variables, name)
        ctx.vector_variables[name] = ResizableArray(NodeLabel, Val(1))
    end
    if !isassigned(ctx.vector_variables[name], index)
        ctx.vector_variables[name][index] =
            add_variable_node!(model, ctx, name; index = index)
    end
    return ctx.vector_variables[name]
end

function getorcreate!(model::Model, ctx::Context, name::Symbol, index...)
    check_if_individual_variable(ctx, name)
    check_if_vector_variable(ctx, name)
    if !haskey(ctx.tensor_variables, name)
        ctx.tensor_variables[name] = ResizableArray(NodeLabel, Val(length(index)))
    end
    if !isassigned(ctx.tensor_variables[name], index...)
        ctx.tensor_variables[name][index...] =
            add_variable_node!(model, ctx, name; index = index)
    end
    return ctx.tensor_variables[name]
end

getifcreated(model::Model, context::Context, var::NodeLabel) = var
getifcreated(model::Model, context::Context, var::ResizableArray) = var
getifcreated(model::Model, context::Context, var::Union{Tuple,AbstractArray{NodeLabel}}) =
    map((v) -> getifcreated(model, context, v), var)
getifcreated(model::Model, context::Context, var) = add_variable_node!(
    model,
    context,
    gensym(model, :constvar);
    __options__ = (value = var,),
)


"""
Add a variable node to the model with the given ID. This function is unsafe (doesn't check if a variable with the given name already exists in the model). 

The function generates a new symbol for the variable and puts it in the
context with the given ID. It then adds a node to the model with the generated
symbol as the key and a `NodeData` struct with `is_variable` set to `true` and
`variable_id` set to the given ID.

Args:
    - `model::Model`: The model to which the node is added.
    - `context::Context`: The context to which the symbol is added.
    - `variable_id::Symbol`: The ID of the variable.
    - `index::Union{Nothing, Int, NTuple{N, Int64} where N} = nothing`: The index of the variable.
    - `options::Dict{Symbol, Any} = nothing`: The options to attach to the NodeData of the variable node.

Returns:
    - The generated symbol for the variable.
"""
function add_variable_node!(
    model::Model,
    context::Context,
    variable_id::Symbol;
    index = nothing,
    __options__ = nothing,
)
    variable_symbol = generate_nodelabel(model, variable_id)
    context[variable_id, index] = variable_symbol
    model[variable_symbol] = VariableNodeData(variable_id, __options__)
    return variable_symbol
end

"""
Add an atomic factor node to the model with the given name.

The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `FactorNodeData` struct.

Args:
    - `model::Model`: The model to which the node is added.
    - `context::Context`: The context to which the symbol is added.
    - `node_name::Any`: The name of the node.

Returns:
    - The generated symbol for the node.
"""
function add_atomic_factor_node!(
    model::Model,
    context::Context,
    node_name,
    interfaces;
    __options__ = nothing,
)
    node_fform = factor_alias(node_name, interfaces)
    node_id = generate_nodelabel(model, node_fform)
    model[node_id] = FactorNodeData(node_fform, __options__)
    context.factor_nodes[to_symbol(node_id)] = node_id
    return node_id
end

factor_alias(any, interfaces) = any
factor_alias(::typeof(+), interfaces) = sum
factor_alias(::typeof(-), interfaces) = sub
factor_alias(::typeof(*), interfaces) = prod
factor_alias(::typeof(/), interfaces) = div

"""
Add a composite factor node to the model with the given name.

The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `NodeData` struct with `is_variable` set to
`false` and `node_name` set to the given name.

Args:
    - `model::Model`: The model to which the node is added.
    - `parent_context::Context`: The context to which the symbol is added.
    - `context::Context`: The context of the composite factor node.
    - `node_name::Symbol`: The name of the node.

Returns:
    - The generated symbol for the node.
"""
function add_composite_factor_node!(
    model::Model,
    parent_context::Context,
    context::Context,
    node_name::Symbol,
)
    node_id = generate_nodelabel(model, node_name)
    parent_context.factor_nodes[to_symbol(node_id)] = context
    return node_id
end

add_composite_factor_node!(
    model::Model,
    parent_context::Context,
    child_context::Context,
    node_name,
) = add_composite_factor_node!(model, parent_context, child_context, Symbol(node_name))

iterator(interfaces::NamedTuple) = zip(keys(interfaces), values(interfaces))

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    variable_node_id::NodeLabel,
    interface_name::Symbol;
    index = 1,
)
    model.graph[variable_node_id, factor_node_id] = EdgeLabel(interface_name, index)
end

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    variable_nodes::Union{AbstractArray{NodeLabel},Tuple,NamedTuple},
    interface_name::Symbol;
    index = 1,
)
    for variable_node in variable_nodes
        add_edge!(model, factor_node_id, variable_node, interface_name; index = index)
        index += increase_index(variable_node)
    end
end
increase_index(any) = 1
increase_index(x::AbstractArray) = length(x)


struct MixedArguments
    args::AbstractArray
    kwargs::NamedTuple
end

"""
Placeholder function that is defined for all Composite nodes and is invoked when inferring what interfaces are missing when a node is called
"""
interfaces(any_f, ::Val{1}) = (:out,)
interfaces(any_f, any_val) = (:out, :in)

"""
    missing_interfaces(node_type, val, known_interfaces)

Returns the interfaces that are missing for a node. This is used when inferring the interfaces for a node that is composite.

# Arguments
- `node_type`: The type of the node as a Function object.
- `val`: The value of the amount of interfaces the node is supposed to have. This is a `Val` object.
- `known_interfaces`: The known interfaces for the node.

# Returns
- `missing_interfaces`: A `Vector` of the missing interfaces.
"""
function missing_interfaces(node_type, val::Val, known_interfaces)
    all_interfaces = GraphPPL.interfaces(node_type, val)
    missing_interfaces = Base.setdiff(all_interfaces, keys(known_interfaces))
    return missing_interfaces
end


function prepare_interfaces(fform, lhs_interface, rhs_interfaces::NamedTuple)
    missing_interface =
        GraphPPL.missing_interfaces(fform, Val(length(rhs_interfaces) + 1), rhs_interfaces)
    @assert length(missing_interface) == 1 "Expected only one missing interface, got $missing_interface of length $(length(missing_interface))"
    missing_interface = first(missing_interface)
    return NamedTuple{(keys(rhs_interfaces)..., missing_interface)}((
        values(rhs_interfaces)...,
        lhs_interface,
    ))
end

rhs_to_named_tuple(::Atomic, fform, rhs) = (in = Tuple(rhs),)
rhs_to_named_tuple(::Composite, fform, rhs) =
    error("Composite nodes always have to be initialized with named arguments")

is_nodelabel(x) = false
is_nodelabel(x::AbstractArray) = any(element -> is_nodelabel(element), x)
is_nodelabel(x::GraphPPL.NodeLabel) = true

function contains_nodelabel(collection::AbstractArray)
    if any(element -> is_nodelabel(element), collection)
        return Val(true)
    else
        return Val(false)
    end
end

function contains_nodelabel(collection::NamedTuple)
    if any(element -> is_nodelabel(element), values(collection))
        return Val(true)
    else
        return Val(false)
    end
end

function contains_nodelabel(collection::MixedArguments)
    if any(element -> is_nodelabel(element), collection.args) ||
       any(element -> is_nodelabel(element), values(collection.kwargs))
        return Val(true)
    else
        return Val(false)
    end
end

# Two-level dispatch for make_node!
# First check if node is Composite or Atomic
make_node!(
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::NodeLabel,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    NodeType(fform),
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

make_node!(
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::NodeLabel,
    rhs_interfaces::Nothing;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    Val(true),
    Atomic(),
    Stochastic(),
    model,
    ctx,
    fform,
    lhs_interface,
    NamedTuple{}();
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

# If node is Atomic, check stochasticity
make_node!(
    ::Atomic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    Atomic(),
    NodeBehaviour(fform),
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)
#If a node is deterministic, we check if there are any NodeLabel objects in the rhs_interfaces (direct check if node should be materialized)
make_node!(
    atomic::Atomic,
    deterministic::Deterministic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    contains_nodelabel(rhs_interfaces),
    atomic,
    deterministic,
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

# If the node should not be materialized (if it's Atomic, Deterministic and contains no NodeLabel objects), we return the function evaluated at the interfaces
make_node!(
    ::Val{false},
    ::Atomic,
    ::Deterministic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::AbstractArray;
    __parent_options__ = nothing,
    __debug__ = false,
) = fform(rhs_interfaces...)

make_node!(
    ::Val{false},
    ::Atomic,
    ::Deterministic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::NamedTuple;
    __parent_options__ = nothing,
    __debug__ = false,
) = fform(; rhs_interfaces...)

make_node!(
    ::Val{false},
    ::Atomic,
    ::Deterministic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::MixedArguments;
    __parent_options__ = nothing,
    __debug__ = false,
) = fform(rhs_interfaces.args...; rhs_interfaces.kwargs...)

# If a node is Stochastic, we always materialize.
make_node!(
    atomic::Atomic,
    stochastic::Stochastic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    Val(true),
    atomic,
    stochastic,
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

# If we have to materialize but the rhs_interfaces argument is not a NamedTuple, we convert it
make_node!(
    ::Val{true},
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::AbstractArray;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    Val(true),
    node_type,
    behaviour,
    model,
    ctx,
    fform,
    lhs_interface,
    GraphPPL.rhs_to_named_tuple(node_type, fform, rhs_interfaces);
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

make_node!(
    ::Val{true},
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::MixedArguments;
    __parent_options__ = nothing,
    __debug__ = false,
) = error(
    "MixedArguments not supported for rhs_interfaces when node has to be materialized",
)

make_node!(
    ::Composite,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    Composite(),
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces,
    Val(length(rhs_interfaces) + 1);
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

# If node has to be materialized and rhs_interfaces is a NamedTuple we actually create a node in the FFG. 
function make_node!(
    ::Val{true},
    ::Atomic,
    ::NodeBehaviour,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::NamedTuple;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)
    interfaces = prepare_interfaces(fform, lhs_interface, rhs_interfaces)
    interface_keys = Val(keys(interfaces))
    node_id = add_atomic_factor_node!(
        model,
        ctx,
        fform,
        interface_keys;
        __options__ = __parent_options__,
    )
    for (interface_name, interface_value) in iterator(interfaces)
        add_edge!(
            model,
            node_id,
            GraphPPL.getifcreated(model, ctx, interface_value),
            interface_name,
        )
    end
    return lhs_interface
end


function plot_graph(g::MetaGraph; name = "tmp.png")
    node_labels =
        [label[2].name for label in sort(collect(g.vertex_labels), by = x -> x[1])]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(name, 16cm, 16cm), plt)
    return plt
end

plot_graph(g::Model; name = "tmp.png") = plot_graph(g.graph; name = name)

function prune!(m::Model)
    degrees = degree(m.graph)
    nodes_to_remove = keys(degrees)[degrees.==0]
    for node in sort(nodes_to_remove, rev = true)
        rem_vertex!(m.graph, node)
    end
end
