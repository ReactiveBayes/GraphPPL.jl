using Graphs
using MetaGraphsNext
import Base:
    put!,
    haskey,
    gensym,
    getindex,
    getproperty,
    setproperty!,
    setindex!,
    length,
    size,
    resize!
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
    name::Symbol
    index::Int64

end

name(label::NodeLabel) = label.name

struct NodeData
    is_variable::Bool
    name::Any
    value::Any
    options::Union{Nothing,Dict}
end

value(node::NodeData) = node.value
options(node::NodeData) = node.options

struct EdgeLabel
    name::Symbol
end


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
function generate_nodelabel(model::Model, name::Symbol)
    increase_count(model)
    return NodeLabel(name, model.counter)
end


function Base.gensym(model::Model, name::Symbol)
    increase_count
    return Symbol(String(name) * "_" * string(model.counter))
end

to_symbol(id::NodeLabel) = Symbol(String(id.name) * "_" * string(id.index))


struct Context
    depth::Int64
    prefix::String
    individual_variables::Dict{Symbol,NodeLabel}
    vector_variables::Dict{Symbol,ResizableArray{NodeLabel}}
    tensor_variables::Dict{Symbol,ResizableArray}
    factor_nodes::Dict{NodeLabel,Union{NodeLabel,Context}}
end

function Base.show(io::IO, context::Context)
    println(io, "$("    " ^ context.depth)Context: $(context.prefix)")
    println(io, "$("    " ^ (context.depth + 1))Individual variables:")
    for (variable_name, variable_label) in context.individual_variables
        println(
            io,
            "$("    " ^ (context.depth + 2))$(variable_name): $(to_symbol(variable_label))",
        )
    end
    println(io, "$("    " ^ (context.depth + 1))Vector variables:")
    for (variable_name, variable_labels) in context.vector_variables
        println(io, "$("    " ^ (context.depth + 2))$(variable_name)")
    end
    println(io, "$("    " ^ (context.depth + 1))Tensor variables: ")
    for (variable_name, variable_labels) in context.tensor_variables
        println(io, "$("    " ^ (context.depth + 2))$(variable_name)")
    end
    println(io, "$("    " ^ (context.depth + 1))Factor nodes: ")
    for (factor_label, factor_context) in context.factor_nodes
        if isa(factor_context, Context)
            show(io, factor_context)
        else
            println(
                io,
                "$("    " ^ (context.depth + 2))$(to_symbol(factor_label)) : $(to_symbol(factor_context))",
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
    end
    throw(KeyError("Variable " * String(key) * " not found in Context " * c.prefix))
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

check_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ?
    error("Variable $name is already an individual variable in the model") : nothing
check_if_vector_variable(context::Context, name::Symbol) =
    haskey(context.vector_variables, name) ?
    error("Variable $name is already a vector variable in the model") : nothing
check_if_tensor_variable(context::Context, name::Symbol) =
    haskey(context.tensor_variables, name) ?
    error("Variable $name is already a tensor variable in the model") : nothing


function getorcreatearray!(model::Model, context::Context, name::Symbol, dim::Val{1})
    # check that the variable does not exist in other categories
    check_if_individual_variable(context, name)
    check_if_tensor_variable(context, name)
    if !haskey(context.vector_variables, name)
        context.vector_variables[name] = ResizableArray(NodeLabel)
    end
    return context.vector_variables[name]
end

function getorcreatearray!(
    model::Model,
    context::Context,
    name::Symbol,
    dim::Val{N},
) where {N}
    # check that the variable does not exist in other categories
    check_if_individual_variable(context, name)
    check_if_vector_variable(context, name)
    # Simply return a variable and create a new one if it does not exist
    if !haskey(context.tensor_variables, name)
        context.tensor_variables[name] = ResizableArray(NodeLabel, dim)
    end
    return context.tensor_variables[name]
end

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
function getorcreate!(model::Model, context::Context, name::Symbol)
    # check that the variable does not exist in other categories
    check_if_vector_variable(context, name)
    check_if_tensor_variable(context, name)
    # Simply return a variable and create a new one if it does not exist
    return get(
        () -> add_variable_node!(model, context, name; index = nothing),
        context.individual_variables,
        name,
    )
end


getorcreate!(model::Model, context::Context, variables::Union{Tuple,AbstractArray}) =
    map((edge) -> getorcreate!(model, context, edge), variables)



function getorcreate!(model::Model, context::Context, name::Symbol, index::Int)
    # check that the variable exists in the current context
    @assert haskey(context.vector_variables, name)
    return get(
        () -> add_variable_node!(model, context, name; index = index),
        context.vector_variables[name],
        index,
    )
end

function getorcreate!(model::Model, context::Context, name::Symbol, index...)
    # check that the variable exists in the current context
    @assert haskey(context.tensor_variables, name)
    # Simply return a variable and create a new one if it does not exist
    if !isassigned(context.tensor_variables[name], index...)
        add_variable_node!(model, context, name; index = index)
    end
    return context.tensor_variables[name][index...]
end

getifcreated(model::Model, context::Context, var::NodeLabel) = var
getifcreated(model::Model, context::Context, var::ResizableArray) = var
getifcreated(model::Model, context::Context, var::Union{Tuple,AbstractArray{NodeLabel}}) =
    map((v) -> getifcreated(model, context, v), var)
getifcreated(model::Model, context::Context, var) =
    add_variable_node!(model, context, gensym(model, :constvar); value = var)

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
    - `value::Union{Nothing, Any} = nothing`: The value of the variable.
    - `options::Dict{Symbol, Any} = nothing`: The options to attach to the NodeData of the variable node.

Returns:
    - The generated symbol for the variable.
"""
function add_variable_node!(
    model::Model,
    context::Context,
    variable_id::Symbol;
    index = nothing,
    value = nothing,
    options = nothing,
)
    variable_symbol = generate_nodelabel(model, variable_id)
    context[variable_id, index] = variable_symbol
    model[variable_symbol] = NodeData(true, variable_id, value, options)
    return variable_symbol
end

"""
Add an atomic factor node to the model with the given name.

The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `NodeData` struct with `is_variable` set to
`false` and `node_name` set to the given name.

Args:
    - `model::Model`: The model to which the node is added.
    - `context::Context`: The context to which the symbol is added.
    - `node_name::Symbol`: The name of the node.

Returns:
    - The generated symbol for the node.
"""
function add_atomic_factor_node!(
    model::Model,
    context::Context,
    node_name::Symbol;
    options = nothing,
)
    node_id = generate_nodelabel(model, Symbol(node_name))
    model[node_id] = NodeData(false, node_name, nothing, options)
    context.factor_nodes[node_id] = node_id
    return node_id
end

add_atomic_factor_node!(
    model::Model,
    context::Context,
    node_name::Real;
    options = nothing,
) = error("Cannot create factor node with Real argument")
add_atomic_factor_node!(model::Model, context::Context, node_name; options = nothing) =
    add_atomic_factor_node!(model, context, Symbol(node_name); options = options)

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
    parent_context.factor_nodes[node_id] = context
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
    interface_name::Symbol,
)
    model.graph[variable_node_id, factor_node_id] = EdgeLabel(interface_name)
end

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    variable_nodes::Union{AbstractArray{NodeLabel},Tuple,NamedTuple},
    interface_name::Symbol,
)
    for (i, variable_node) in enumerate(variable_nodes)
        add_edge!(
            model,
            factor_node_id,
            variable_node,
            Symbol(String(interface_name) * "_" * string(i)),
        )
    end
end

function make_node!(
    model::Model,
    ::Atomic,
    context::Context,
    node_name,
    interfaces::NamedTuple;
    options = nothing,
    debug = false,
)
    factor_node_id = add_atomic_factor_node!(model, context, node_name; options = options)
    for (interface_name, variable_name) in iterator(interfaces)
        add_edge!(model, factor_node_id, variable_name, interface_name)
    end
    return factor_node_id
end


make_node!(
    model::Model,
    parent_context::Context,
    node_name,
    interfaces::NamedTuple;
    options = nothing,
    debug = false,
) = make_node!(
    model::Model,
    NodeType(node_name),
    parent_context::Context,
    node_name,
    interfaces;
    options = options,
    debug = debug,
)

make_node_from_object!(model::Model, context::Context, node::NodeLabel, lhs, index...) =
    node

function make_node_from_object!(model::Model, context::Context, distribution, lhs, index...)
    node_name = typeof(distribution)
    interfaces = fieldnames(node_name)
    values = [
        GraphPPL.getifcreated(model, context, getfield(distribution, field)) for
        field in interfaces
    ]
    interfaces = (interfaces..., :out)
    if length(index) == 0
        new_interface_variable = GraphPPL.getorcreate!(model, context, lhs)
    else
        new_interface_variable = GraphPPL.getorcreate!(model, context, lhs, index...)
    end
    values = (values..., new_interface_variable)
    GraphPPL.make_node!(model, context, node_name, NamedTuple{interfaces}(values))
    return new_interface_variable
end

function plot_graph(g::MetaGraph; name = "tmp.png")
    node_labels =
        [label[2].name for label in sort(collect(g.vertex_labels), by = x -> x[1])]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(name, 16cm, 16cm), plt)
    return plt
end

plot_graph(g::Model; name = "tmp.png") = plot_graph(g.graph; name = name)
