using Graphs
using MetaGraphsNext
import Base:
    put!, haskey, gensym, getindex, getproperty, setproperty!, setindex!, vec, iterate
using BitSetTuples
using Static

struct Broadcasted
    name::Symbol
end

getname(broadcasted::Broadcasted) = broadcasted.name

struct FactorID
    fform::Any
    index::Int64
end

fform(id::FactorID) = id.fform
index(id::FactorID) = id.index

Base.show(io::IO, id::FactorID) = print(io, "(", fform(id), ", ", index(id), ")")

"""
    Model(graph::MetaGraph)

Materialized Factor Graph type.

A structure representing a probabilistic graphical model. It contains a `MetaGraph` object
representing the factor graph and a `Base.RefValue{Int64}` object to keep track of the number
of nodes in the graph.

Fields:
- `graph`: A `MetaGraph` object representing the factor graph.
- `counter`: A `Base.RefValue{Int64}` object keeping track of the number of nodes in the graph.
"""
struct Model
    graph::MetaGraph
    counter::Base.RefValue{Int64}
end

"""
    NodeLabel(name::Symbol, global_counter::Int64)

Unique identifier for a node in a probabilistic graphical model.

A structure representing a node in a probabilistic graphical model. It contains a symbol
representing the name of the node, an integer representing the unique identifier of the node,
a UInt8 representing the type of the variable, and an integer or tuple of integers representing
the global_counter of the variable.
"""
struct NodeLabel
    name::Any
    global_counter::Int64
end


Base.length(label::NodeLabel) = 1

getname(label::NodeLabel) = label.name
getname(labels::ResizableArray{T,V,N} where {T<:NodeLabel,V,N}) = getname(first(labels))
vec(label::NodeLabel) = [label]
iterate(label::NodeLabel) = (label, nothing)
iterate(label::NodeLabel, any) = nothing
unroll(label) = label

Base.show(io::IO, label::NodeLabel) = print(io, label.name, "_", label.global_counter)
Base.getindex(label::NodeLabel, ::Any) = label

"""
    VariableNodeData(name::Symbol, options::NamedTuple)

Data associated with a variable node in a probabilistic graphical model.
"""
mutable struct VariableNodeData
    name::Symbol
    options::NamedTuple
    index::Any
    context::Any
end


value(node::VariableNodeData) = node.options[:value]
fform_constraint(node::VariableNodeData) = node.options[:q]
getname(node::VariableNodeData) = node.name
index(node::VariableNodeData) = node.index
getcontext(node::VariableNodeData) = node.context

Base.show(io::IO, node::VariableNodeData) = print(
    io,
    node.name,
    "[",
    node.index,
    "] in context ",
    node.context.prefix,
    "_",
    node.context.fform,
)

"""
    FactorNodeData(fform::Any, options::NamedTuple)

Data associated with a factor node in a probabilistic graphical model.
"""
mutable struct FactorNodeData
    fform::Any
    options::NamedTuple
end

factorization_constraint(node::FactorNodeData) = node.options[:q]

const NodeData = Union{FactorNodeData,VariableNodeData}

node_options(node::NodeData) = node.options
add_to_node_options!(node::NodeData, name::Symbol, value) =
    node.options = merge(node_options(node), (name => value,))
is_constant(node::NodeData) = node_options(node)[:constant]

struct ProxyLabel{T}
    name::Symbol
    index::T
    proxied::Any
end

getname(label::ProxyLabel) = label.name
index(label::ProxyLabel) = label.index

unroll(proxy::ProxyLabel) = __proxy_unroll(proxy)

__proxy_unroll(something) = something
__proxy_unroll(proxy::ProxyLabel) = __proxy_unroll(proxy.index, proxy)
__proxy_unroll(::Nothing, proxy::ProxyLabel) = __proxy_unroll(proxy.proxied)
__proxy_unroll(index, proxy::ProxyLabel) = __proxy_unroll(proxy.proxied)[index...]
__proxy_unroll(index::FunctionalIndex, proxy::ProxyLabel) =
    __proxy_unroll(proxy.proxied)[index]

Base.show(io::IO, proxy::ProxyLabel{NTuple{N,Int}} where {N}) =
    print(io, getname(proxy), "[", index(proxy), "]")
Base.show(io::IO, proxy::ProxyLabel{Nothing}) = print(io, getname(proxy))
Base.show(io::IO, proxy::ProxyLabel) = print(io, getname(proxy), "[", index(proxy)[1], "]")
Base.getindex(proxy::ProxyLabel, indices...) = getindex(unroll(proxy), indices...)

Base.last(label::ProxyLabel) = last(label.proxied, label)

Base.last(proxied::ProxyLabel, ::ProxyLabel) = last(proxied)
Base.last(proxied, ::ProxyLabel) = proxied

struct EdgeLabel
    name::Symbol
    index::Union{Int,Nothing}
end

getname(label::EdgeLabel) = label.name

to_symbol(label::EdgeLabel) = to_symbol(label, label.index)
to_symbol(label::EdgeLabel, ::Nothing) = label.name
to_symbol(label::EdgeLabel, ::Int64) =
    Symbol(string(label.name) * "[" * string(label.index) * "]")

Base.show(io::IO, label::EdgeLabel) = print(io, to_symbol(label))

Model(graph::MetaGraph) = Model(graph, Base.RefValue(0))


Base.setindex!(model::Model, val::NodeData, key::NodeLabel) =
    Base.setindex!(model.graph, val, key)
Base.setindex!(model::Model, val::EdgeLabel, src::NodeLabel, dst::NodeLabel) =
    Base.setindex!(model.graph, val, src, dst)
Base.getindex(model::Model) = Base.getindex(model.graph)
Base.getindex(model::Model, key::NodeLabel) = Base.getindex(model.graph, key)
Base.getindex(model::Model, src::NodeLabel, dst::NodeLabel) =
    Base.getindex(model.graph, src, dst)
Base.getindex(model::Model, keys::AbstractArray{NodeLabel}) = [model[key] for key in keys]


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
MetaGraphsNext.label_for(model::Model, node_id::Int) =
    MetaGraphsNext.label_for(model.graph, node_id)

function retrieve_interface_position(interfaces, x::EdgeLabel, max_length::Int)
    index = x.index === nothing ? 0 : x.index
    position = findfirst(isequal(x.name), interfaces)
    position =
        position === nothing ?
        begin
            @warn(lazy"Interface $(x.name) not found in $interfaces")
            0
        end : position
    return max_length * findfirst(isequal(x.name), interfaces) + index
end

function __sortperm(model::Model, node::NodeLabel, edges::AbstractArray)
    fform = model[node].fform
    indices = [e.index for e in edges]
    names = unique([e.name for e in edges])
    interfaces = GraphPPL.interfaces(fform, static(length(names)))
    max_length = any(x -> x !== nothing, indices) ? maximum(indices[indices.!=nothing]) : 1
    perm =
        sortperm(edges, by = (x -> retrieve_interface_position(interfaces, x, max_length)))
    return perm
end

__get_neighbors(model::Model, node::NodeLabel) =
    label_for.(
        (model.graph,),
        collect(MetaGraphsNext.neighbors(model.graph, code_for(model.graph, node))),
    )
__neighbors(model::Model, node::NodeLabel; sorted = false) =
    __neighbors(model, node, model[node]; sorted = sorted)
__neighbors(model::Model, node::NodeLabel, node_data::VariableNodeData; sorted = false) =
    __get_neighbors(model, node)
__neighbors(model::Model, node::NodeLabel, node_data::FactorNodeData; sorted = false) =
    __neighbors(model, node, static(sorted))
__neighbors(model::Model, node::NodeLabel, ::False) = __get_neighbors(model, node)
function __neighbors(model::Model, node::NodeLabel, ::True)
    neighbors = __get_neighbors(model, node)
    edges = __get_edges(model, node, neighbors)
    perm = __sortperm(model, node, edges)
    return neighbors[perm]
end
Graphs.neighbors(model::Model, node::NodeLabel; sorted = false) =
    __neighbors(model, node; sorted = sorted)
Graphs.neighbors(model::Model, nodes::AbstractArray; sorted = false) =
    union(Graphs.neighbors.(Ref(model), nodes; sorted = sorted)...)
Graphs.vertices(model::Model) = MetaGraphsNext.vertices(model.graph)


__get_edges(model::Model, node::NodeLabel, neighbors) =
    getindex.(Ref(model), Ref(node), neighbors)
__edges(model::Model, node::NodeLabel, node_data::VariableNodeData; sorted = false) =
    __get_edges(model, node, __get_neighbors(model, node))
__edges(model::Model, node::NodeLabel, node_data::FactorNodeData; sorted = false) =
    __edges(model, node, static(sorted))
__edges(model::Model, node::NodeLabel, ::False) =
    __get_edges(model, node, __get_neighbors(model, node))
function __edges(model::Model, node::NodeLabel, ::True)
    neighbors = __get_neighbors(model, node)
    edges = __get_edges(model, node, neighbors)
    perm = __sortperm(model, node, edges)
    return edges[perm]
end
Graphs.edges(model::Model, node::NodeLabel; sorted = false) =
    __edges(model, node, model[node]; sorted = sorted)

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
    increase_count(model)
    return Symbol(String(name) * "_" * string(model.counter))
end


"""
    Context

Contains all information about a submodel in a probabilistic graphical model.

"""
struct Context
    depth::Int64
    fform::Function
    prefix::String
    parent::Union{Context,Nothing}
    children::Dict{FactorID,Context}
    individual_variables::Dict{Symbol,NodeLabel}
    vector_variables::Dict{Symbol,ResizableArray{NodeLabel}}
    tensor_variables::Dict{Symbol,ResizableArray}
    factor_nodes::Dict{FactorID,NodeLabel}
    proxies::Dict{Symbol,ProxyLabel}
    submodel_counts::Dict{Any,Int}
end

fform(context::Context) = context.fform
parent(context::Context) = context.parent
individual_variables(context::Context) = context.individual_variables
vector_variables(context::Context) = context.vector_variables
tensor_variables(context::Context) = context.tensor_variables
factor_nodes(context::Context) = context.factor_nodes
proxies(context::Context) = context.proxies
children(context::Context) = context.children
count(context::Context, fform::Any) =
    haskey(context.submodel_counts, fform) ? context.submodel_counts[fform] : 0

function generate_factor_nodelabel(context::Context, fform::Any)
    if count(context, fform) == 0
        context.submodel_counts[fform] = 1
    else
        context.submodel_counts[fform] += 1
    end
    return FactorID(fform, count(context, fform))
end


function Base.show(io::IO, context::Context)
    indentation = 2 * context.depth
    println(io, "$("    " ^ indentation)Context: $(context.prefix)")
    println(io, "$("    " ^ (indentation + 1))Individual variables:")
    for (variable_name, variable_label) in context.individual_variables
        println(io, "$("    " ^ (indentation + 2))$(variable_name): $(variable_label)")
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
            println(io, "$("    " ^ (indentation + 2))$(factor_label) : $(factor_context)")
        end
    end
    println(io, "$("    " ^ (indentation + 1))Child Contexts: ")
    for (child_name, child_context) in context.children
        println(io, "$("    " ^ (indentation + 2))$(child_name) : ")
        show(io, child_context)
    end
    println(io, "$("    " ^ (indentation + 1))Proxies from parent: ")
    for (proxy_name, proxy_label) in context.proxies
        println(io, "$("    " ^ (indentation + 2))$(proxy_name) : $(proxy_label)")
    end
end

getname(f::Function) = String(Symbol(f))

Context(depth::Int, fform::Function, prefix::String, parent) = Context(
    depth,
    fform,
    prefix,
    parent,
    Dict(),
    Dict(),
    Dict(),
    Dict(),
    Dict(),
    Dict(),
    Dict(),
)

Context(parent::Context, model_fform::Function) = Context(
    parent.depth + 1,
    model_fform,
    (parent.prefix == "" ? parent.prefix : parent.prefix * "_") * getname(model_fform),
    parent,
)
Context() = Context(0, identity, "", nothing)

haskey(context::Context, key::Symbol) =
    haskey(context.individual_variables, key) ||
    haskey(context.vector_variables, key) ||
    haskey(context.tensor_variables, key) ||
    haskey(context.factor_nodes, key) ||
    haskey(context.children, key)

hasvariable(contexct::Context, key::Symbol) =
    haskey(context.individual_variables, key) ||
    haskey(context.vector_variables, key) ||
    haskey(context.tensor_variables, key)

function Base.getindex(c::Context, key::Any)
    if haskey(c.individual_variables, key)
        return c.individual_variables[key]
    elseif haskey(c.vector_variables, key)
        return c.vector_variables[key]
    elseif haskey(c.tensor_variables, key)
        return c.tensor_variables[key]
    elseif haskey(c.factor_nodes, key)
        return c.factor_nodes[key]
    elseif haskey(c.children, key)
        return c.children[key]
    elseif haskey(c.proxies, key)
        return c.proxies[key]
    end
    throw(KeyError(key))
end

function Base.getindex(c::Context, fform, index::Int)
    return c[FactorID(fform, index)]
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

Base.setindex!(c::Context, val::ResizableArray{NodeLabel,T,1} where {T}, key::Symbol) =
    c.vector_variables[key] = val

Base.setindex!(c::Context, val::ResizableArray{NodeLabel,T,N} where {T,N}, key::Symbol) =
    c.tensor_variables[key] = val


getcontext(model::Model) = model.graph[]
function get_principal_submodel(model::Model)
    context = getcontext(model)
    return context
end

Base.getindex(context::Context, index::IndexedVariable{Nothing}) = context[index.variable]
Base.getindex(context::Context, index::IndexedVariable) =
    context[index.variable][index.index]

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

The Markov blanket of a node or model in a Factor Graph is defined as the set of its outgoing interfaces. 
This function copies the variables in the Markov blanket of the parent context specified by the named tuple `interfaces` to the child context `child_context`, 
    by setting each child variable in `child_context.individual_variables` to its corresponding parent variable in `interfaces`.

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

add_to_child_context(
    child_context::Context,
    name_in_child::Symbol,
    object_in_parent::ResizableArray{NodeLabel,V,1},
) where {V} = child_context.vector_variables[name_in_child] = object_in_parent

add_to_child_context(
    child_context::Context,
    name_in_child::Symbol,
    object_in_parent::ResizableArray{NodeLabel,V,N},
) where {V,N} = child_context.tensor_variables[name_in_child] = object_in_parent

add_to_child_context(
    child_context::Context,
    name_in_child::Symbol,
    object_in_parent::ProxyLabel,
) = child_context.proxies[name_in_child] = object_in_parent

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


""" 
    check_variabe_compatability(node, index)

Will check if the index is compatible with the node object that is passed.

"""
check_variate_compatability(node::NodeLabel, index::Nothing) = true
check_variate_compatability(node::NodeLabel, index) = error(
    "Cannot call single random variable on the left-hand-side by an indexed statement",
)

check_variate_compatability(label::GraphPPL.ProxyLabel, index) =
    check_variate_compatability(unroll(label), index)

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

This function searches for a variable (edge) in the factor graph model and context specified by the arguments `model` and `context`. If the variable exists, 
it returns it. Otherwise, it creates a new variable and returns it.

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
getifcreated(model::Model, context::Context, var::ProxyLabel) = var
getifcreated(model::Model, context::Context, var) = add_variable_node!(
    model,
    context,
    gensym(model, :constvar);
    __options__ = NamedTuple{(:value, :constant)}((var, true)),
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
    __options__ = NamedTuple{(:constant,)}((false,)),
)
    variable_symbol = generate_nodelabel(model, variable_id)
    context[variable_id, index] = variable_symbol
    model[variable_symbol] = VariableNodeData(variable_id, __options__, index, context)
    return variable_symbol
end

function create_anonymous_variable!(model::Model, context::Context)
    return add_variable_node!(model, context, :anonymous)
    # TODO add some proxying here that links "children" of this anonymous variable and this together. Necessary for applying constraints.
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
    fform;
    __options__ = NamedTuple{}(),
)
    __options__ = __options__ === nothing ? NamedTuple{}() : __options__
    factornode_id = generate_factor_nodelabel(context, fform)
    factornode_label = generate_nodelabel(model, fform)
    model[factornode_label] = FactorNodeData(fform, __options__)
    context.factor_nodes[factornode_id] = factornode_label
    return factornode_label
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
    node_name,
)
    node_id = generate_factor_nodelabel(parent_context, node_name)
    parent_context.children[node_id] = context
    return node_id
end

iterator(interfaces::NamedTuple) = zip(keys(interfaces), values(interfaces))

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    variable_node_id::Union{ProxyLabel,NodeLabel},
    interface_name::Symbol;
    index = nothing,
)
    model.graph[unroll(variable_node_id), factor_node_id] = EdgeLabel(interface_name, index)
end

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    variable_nodes::Union{AbstractArray,Tuple,NamedTuple},
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

function add_factorization_constraint!(model::Model, factor_node_id::NodeLabel)
    out_degree = outdegree(model.graph, code_for(model.graph, factor_node_id))
    constraint = BitSetTuple(out_degree)
    for (i, neighbor) in enumerate(neighbors(model, factor_node_id))
        if is_constant(model[neighbor])
            for j = 1:out_degree
                if i != j
                    delete!(constraint[j], i)
                else
                    intersect!(constraint[i], BitSet(i))
                end
            end
        end
    end
    add_to_node_options!(model[factor_node_id], :q, constraint)
end


struct MixedArguments
    args::AbstractArray
    kwargs::NamedTuple
end

"""
Placeholder function that is defined for all Composite nodes and is invoked when inferring what interfaces are missing when a node is called
"""
interfaces(any_f, ::StaticInt{1}) = (:out,)
interfaces(any_f, any_val) = (:out, :in)

"""
    missing_interfaces(node_type, val, known_interfaces)

Returns the interfaces that are missing for a node. This is used when inferring the interfaces for a node that is composite.

# Arguments
- `node_type`: The type of the node as a Function object.
- `val`: The value of the amount of interfaces the node is supposed to have. This is a `Static.StaticInt` object.
- `known_interfaces`: The known interfaces for the node.

# Returns
- `missing_interfaces`: A `Vector` of the missing interfaces.
"""
function missing_interfaces(node_type, val::StaticInt{N} where {N}, known_interfaces)
    all_interfaces = GraphPPL.interfaces(node_type, val)
    missing_interfaces = Base.setdiff(all_interfaces, keys(known_interfaces))
    return missing_interfaces
end


function prepare_interfaces(fform, lhs_interface, rhs_interfaces::NamedTuple)
    missing_interface = GraphPPL.missing_interfaces(
        fform,
        static(length(rhs_interfaces) + 1),
        rhs_interfaces,
    )
    @assert length(missing_interface) == 1 lazy"Expected only one missing interface, got $missing_interface of length $(length(missing_interface)) (node $fform with interfaces $(keys(rhs_interfaces)))))"
    missing_interface = first(missing_interface)
    # TODO check if we can construct NamedTuples a bit faster somewhere.
    return NamedTuple{(missing_interface, keys(rhs_interfaces)...)}((
        lhs_interface,
        values(rhs_interfaces)...,
    ))
end

default_parametrization(::Atomic, fform, rhs) = (in = Tuple(rhs),)
default_parametrization(::Composite, fform, rhs) =
    error("Composite nodes always have to be initialized with named arguments")

# maybe change name

is_nodelabel(x) = false
is_nodelabel(x::AbstractArray) = any(element -> is_nodelabel(element), x)
is_nodelabel(x::GraphPPL.NodeLabel) = true
is_nodelabel(x::ProxyLabel) = true

function contains_nodelabel(collection::AbstractArray)
    if any(element -> is_nodelabel(element), collection)
        return True()
    else
        return False()
    end
end

function contains_nodelabel(collection::NamedTuple)
    if any(element -> is_nodelabel(element), values(collection))
        return True()
    else
        return False()
    end
end

function contains_nodelabel(collection::MixedArguments)
    if any(element -> is_nodelabel(element), collection.args) ||
       any(element -> is_nodelabel(element), values(collection.kwargs))
        return True()
    else
        return False()
    end
end

# TODO improve documentation
# First check if node is Composite or Atomic
make_node!(
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
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

#if it is composite, we assume it should be materialized and it is stochastic
make_node!(
    nodetype::Composite,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    True(),
    nodetype,
    Stochastic(),
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

# If a node is an object and not a function, we materialize it as a stochastic atomic node
make_node!(
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces::Nothing;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    True(),
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
    ::False,
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
    ::False,
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
    ::False,
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
    node_type::Atomic,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    True(),
    Atomic(),
    Stochastic(),
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces;
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

# If we have to materialize but lhs_interface is nothing, we create a variable for it
function make_node!(
    materialize::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::Broadcasted,
    rhs_interfaces;
    __parent_options__ = nothing,
    __debug__ = false,
)
    lhs_node = ProxyLabel(
        getname(lhs_interface),
        nothing,
        add_variable_node!(model, ctx, gensym(getname(lhs_interface))),
    )
    return make_node!(
        True(),
        node_type,
        behaviour,
        model,
        ctx,
        fform,
        lhs_node,
        rhs_interfaces;
        __parent_options__ = __parent_options__,
        __debug__ = __debug__,
    )
end

# If we have to materialize but the rhs_interfaces argument is not a NamedTuple, we convert it
make_node!(
    materialize::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::Union{NodeLabel,ProxyLabel},
    rhs_interfaces::AbstractArray;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    True(),
    node_type,
    behaviour,
    model,
    ctx,
    fform,
    lhs_interface,
    GraphPPL.default_parametrization(node_type, fform, rhs_interfaces);
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

make_node!(
    ::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::Union{NodeLabel,ProxyLabel},
    rhs_interfaces::MixedArguments;
    __parent_options__ = nothing,
    __debug__ = false,
) = error(
    "MixedArguments not supported for rhs_interfaces when node has to be materialized",
)

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::Union{NodeLabel,ProxyLabel},
    rhs_interfaces::AbstractArray;
    __parent_options__ = nothing,
    __debug__ = false,
) =
    length(rhs_interfaces) == 0 ?
    make_node!(
        True(),
        Composite(),
        Stochastic(),
        model,
        ctx,
        fform,
        lhs_interface,
        NamedTuple{}();
        __parent_options__ = __parent_options__,
        __debug__ = __debug__,
    ) :
    error(
        lazy"Composite node $fform cannot be called with an Array as interfaces, should be called with a NamedTuple",
    )

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    fform,
    lhs_interface::Union{NodeLabel,ProxyLabel},
    rhs_interfaces::NamedTuple;
    __parent_options__ = nothing,
    __debug__ = false,
) = make_node!(
    Composite(),
    model,
    ctx,
    fform,
    lhs_interface,
    rhs_interfaces,
    static(length(rhs_interfaces) + 1);
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

"""
    make_node!

Make a new factor node in the Model and specified Context, attach it to the specified interfaces, and return the interface that is on the lhs of the `~` operator.

# Arguments
- `model::Model`: The model to add the node to.
- `ctx::Context`: The context in which to add the node.
- `fform`: The function that the node represents.
- `lhs_interface`: The interface that is on the lhs of the `~` operator.
- `rhs_interfaces`: The interfaces that are the arguments of fform on the rhs of the `~` operator.
- `__parent_options__::NamedTuple = nothing`: The options to attach to the node.
- `__debug__::Bool = false`: Whether to attach debug information to the factor node.
"""
function make_node!(
    materialize::True,
    node_type::Atomic,
    behaviour::NodeBehaviour,
    model::Model,
    context::Context,
    fform,
    lhs_interface::Union{NodeLabel,ProxyLabel},
    rhs_interfaces::NamedTuple;
    __parent_options__ = nothing,
    __debug__ = false,
)
    fform = factor_alias(fform, Val(keys(rhs_interfaces)))
    interfaces = prepare_interfaces(fform, lhs_interface, rhs_interfaces)
    materialize_factor_node!(
        model,
        context,
        fform,
        interfaces;
        __parent_options__ = __parent_options__,
        __debug__ = __debug__,
    )
    return unroll(lhs_interface)
end

function materialize_factor_node!(
    model::Model,
    context::Context,
    fform,
    interfaces::NamedTuple;
    __parent_options__ = nothing,
    __debug__ = false,
)
    factor_node_id =
        add_atomic_factor_node!(model, context, fform; __options__ = __parent_options__)
    for (interface_name, neighbor_nodelabel) in iterator(interfaces)
        add_edge!(
            model,
            factor_node_id,
            GraphPPL.getifcreated(model, context, neighbor_nodelabel),
            interface_name,
        )
    end
    add_factorization_constraint!(model, factor_node_id)
end

add_terminated_submodel!(
    __model__::Model,
    __context__::Context,
    fform,
    __interfaces__::NamedTuple;
    __parent_options__ = nothing,
    __debug__ = false,
) = add_terminated_submodel!(
    __model__,
    __context__,
    fform,
    __interfaces__,
    static(length(__interfaces__));
    __parent_options__ = __parent_options__,
    __debug__ = __debug__,
)

"""
    prune!(m::Model)

Remove all nodes from the model that are not connected to any other node.
"""
function prune!(m::Model)
    degrees = degree(m.graph)
    nodes_to_remove = keys(degrees)[degrees.==0]
    nodes_to_remove = sort(nodes_to_remove, rev = true)
    rem_vertex!.(Ref(m.graph), nodes_to_remove)
end
