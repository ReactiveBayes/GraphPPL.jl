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

struct NodeLabel
    name::Symbol
    index::Int64
    variable_type::UInt8
    variable_index::Union{Int64,NTuple{N,Int64} where N}
end

NodeLabel(
    name::Symbol,
    index::Int64,
    variable_type::Int64,
    variable_index::Union{Int64,NTuple{N,Int64} where N},
) = NodeLabel(name, index, UInt8(variable_type), variable_index)

name(label::NodeLabel) = label.name

struct NodeData
    is_variable::Bool
    name::Any
    value::Any
end

value(node::NodeData) = node.value
NodeData(is_variable::Bool, name::Any) = NodeData(is_variable, name, nothing)

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
    gensym(model::Model, name::Symbol)

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
function gensym(
    model::Model,
    name::Symbol,
    variable_type::UInt8 = UInt8(0),
    index::Union{Int64,NTuple{N,Int64} where N} = 0,
)
    increase_count(model)
    return NodeLabel(name, model.counter, variable_type, index)
end

gensym(model::Model, name::Symbol, index::Nothing) = gensym(model, name, UInt8(1), 0)
gensym(model::Model, name::Symbol, index::Int64) = gensym(model, name, UInt8(2), index)
gensym(model::Model, name::Symbol, index::NTuple{N,Int64} where {N}) =
    gensym(model, name, UInt8(3), index)
gensym(model::Model, name::Symbol, index::Tuple) = throw(
    ArgumentError(
        "Index, if provided, must be an integer or tuple of integers, not a $(typeof(index))",
    ),
)

gensym(model::Model, name, index = nothing) = gensym(model::Model, Symbol(name), index)

to_symbol(id::NodeLabel) = Symbol(String(id.name) * "_" * string(id.index))


struct Context
    prefix::String
    individual_variables::Dict{Symbol,NodeLabel}
    vector_variables::Dict{Symbol,ResizableArray{NodeLabel}}
    tensor_variables::Dict{Symbol,ResizableArray}
    factor_nodes::Dict{NodeLabel,Union{NodeLabel,Context}}
end


name(f::Function) = String(Symbol(f))

Context(prefix::String) = Context(prefix, Dict(), Dict(), Dict(), Dict())
Context(parent::Context, model_name::String) = Context(parent.prefix * model_name * "_")
Context(parent::Context, model_name::Function) = Context(parent, name(model_name))
Context() = Context("")

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
    if !haskey(c.vector_variables, key)
        c.vector_variables[key] = ResizableArray(NodeLabel)
    end
    return c.vector_variables[key][index] = val
end

function Base.setindex!(
    c::Context,
    val::NodeLabel,
    key::Symbol,
    index::NTuple{N,Int64},
) where {N}
    if !haskey(c.tensor_variables, key)
        c.tensor_variables[key] = ResizableArray(NodeLabel, Val(N))
    end
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
        Label = NodeLabel,
        VertexData = NodeData,
        graph_data = Context(),
        EdgeData = EdgeLabel,
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
    for (child_name, parent_name) in iterator(interfaces)
        child_context.individual_variables[child_name] = parent_name
    end
end

getorcreate!(model::Model, something) =
    getorcreate!(model, context(model), something, nothing)
getorcreate!(model::Model, context::Context, edge::Symbol) =
    getorcreate!(model, context, edge, nothing)
getorcreate!(model::Model, context::Context, variables::Union{Tuple,AbstractArray}, index) =
    map((edge) -> getorcreate!(model, context, edge, index), variables)

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
function getorcreate!(model::Model, context::Context, name::Symbol, index::Nothing)
    # check that the variable does not exist in other categories
    if haskey(context.vector_variables, name) || haskey(context.tensor_variables, name)
        error(
            "Variable $name already exists in the model either as vector or as tensor variable and can hence not be defined as individual variable.",
        )
    end
    # Simply return a variable and create a new one if it does not exist
    return get(
        () -> add_variable_node!(model, context, name, index),
        context.individual_variables,
        name,
    )
end

function getorcreate!(model::Model, context::Context, name::Symbol, index::Int)
    # check that the variable does not exist in other categories
    if haskey(context.individual_variables, name) || haskey(context.tensor_variables, name)
        error(
            "Variable $name already exists in the model either as individual or as tensor variable and can hence not be defined as vector variable.",
        )
    end
    if !haskey(context.vector_variables, name)
        add_variable_node!(model, context, name, index)
    else
        get(
            () -> add_variable_node!(model, context, name, index),
            context.vector_variables[name],
            index,
        )
    end
    return context.vector_variables[name]
end

function getorcreate!(model::Model, context::Context, name::Symbol, index...)
    # check that the variable does not exist in other categories
    if haskey(context.individual_variables, name) || haskey(context.vector_variables, name)
        error(
            "Variable $name already exists in the model either as individual or as vector variable and can hence not be defined as $N-dimensional tensor variable.",
        )
    end
    # Simply return a variable and create a new one if it does not exist
    if !haskey(context.tensor_variables, name)
        add_variable_node!(model, context, name, index)
    elseif !isassigned(context.tensor_variables[name], index...)
        add_variable_node!(model, context, name, index)
    else
        get(
            () -> add_variable_node!(model, context, name, index),
            context.tensor_variables[name],
            index,
        )
    end
    return context.tensor_variables[name]
end

getifcreated(model::Model, context::Context, var::NodeLabel) = var
getifcreated(model::Model, context::Context, var::Union{Real, AbstractVector}) = add_variable_node!(model, context, gensym(:constvar), nothing, var)
getifcreated(model::Model, context::Context, var::Tuple) = map((v) -> getifcreated(model, context, v), var)
getifcreated(model::Model, context::Context, var::Symbol) = haskey(context, var) ? context[var] : nothing

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

Returns:
    - The generated symbol for the variable.
"""
function add_variable_node!(
    model::Model,
    context::Context,
    variable_id::Symbol,
    index = nothing,
    value = nothing,
)
    variable_symbol = gensym(model, variable_id, index)
    context[variable_id, index] = variable_symbol
    model[variable_symbol] = NodeData(true, variable_id, value)
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
function add_atomic_factor_node!(model::Model, context::Context, node_name::Symbol)
    node_id = gensym(model, Symbol(node_name), UInt8(0))
    model[node_id] = NodeData(false, node_name)
    context.factor_nodes[node_id] = node_id
    return node_id
end

add_atomic_factor_node!(model::Model, context::Context, node_name::Real) =
    throw(MethodError("Cannot create factor node with Real argument"))
add_atomic_factor_node!(model::Model, context::Context, node_name) =
    add_atomic_factor_node!(model, context, Symbol(node_name))

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
    node_id = gensym(model, node_name)
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


function add_edge(model::Model, factor_node_id::NodeLabel, variable_node_id::Real)
    add_variable_node!(model, model.context, variable_node_id)
    model.graph[variable_node_id, factor_node_id] = EdgeLabel()
end

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
    interfaces::NamedTuple,
)
    factor_node_id = add_atomic_factor_node!(model, context, node_name)
    for (interface_name, variable_name) in iterator(interfaces)
        add_edge!(model, factor_node_id, variable_name, interface_name)
    end
    return factor_node_id
end


make_node!(model::Model, parent_context::Context, node_name, interfaces::NamedTuple) =
    make_node!(
        model::Model,
        NodeType(node_name),
        parent_context::Context,
        node_name,
        interfaces,
    )


function equality_node end

function equality_block end

NodeType(::typeof(equality_block)) = Composite()

function make_node!(
    model::Model,
    ::Composite,
    parent_context::Context,
    node_name::typeof(equality_block),
    interfaces,
)
    if length(interfaces) == 3
        make_node!(model, parent_context, equality_node, interfaces)
        return
    end

    context = Context(parent_context, node_name)
    copy_markov_blanket_to_child_context(context, interfaces)


    first_input = context[keys(interfaces)[1]]
    second_input = context[keys(interfaces)[2]]
    current_terminal = add_variable_node!(model, context, first_input.name)
    make_node!(
        model,
        context,
        equality_node,
        (in1 = first_input, in2 = second_input, in3 = current_terminal),
    )
    for i in range(3, length(interfaces) - 2)
        new_terminal = add_variable_node!(model, context, gensym(first_input.name))
        current_input = context[keys(interfaces)[i]]
        make_node!(
            model,
            context,
            equality_node,
            (in1 = current_terminal, in2 = current_input, in3 = new_terminal),
        )
        current_terminal = new_terminal
    end
    second_to_last_input = context[keys(interfaces)[length(interfaces)-1]]
    last_input = context[keys(interfaces)[length(interfaces)]]
    make_node!(
        model,
        context,
        equality_node,
        (in1 = current_terminal, in2 = second_to_last_input, in3 = last_input),
    )

    node_id = gensym(model, node_name)
    parent_context.factor_nodes[node_id] = context

end

function plot_graph(g::MetaGraph; name = "tmp.png")
    node_labels =
        [label[2].name for label in sort(collect(g.vertex_labels), by = x -> x[1])]
    plt = gplot(g, nodelabel = node_labels)
    draw(PNG(name, 16cm, 16cm), plt)
    return plt
end

plot_graph(g::Model; name = "tmp.png") = plot_graph(g.graph; name = name)

is_variable_node(model::MetaGraph, vertex::Int) =
    model[label_for(model, vertex)].is_variable

function terminate_at_neighbors!(model::Model, vertex)
    label = label_for(model.graph, vertex)
    name = model[label].name
    new_vertices = Dict()
    for neighbor in neighbors(model.graph, vertex)
        new_label = gensym(model, name)
        model[new_label] = NodeData(true, name)
        edge_data = model.graph[label, label_for(model.graph, neighbor)]
        model.graph[label_for(model.graph, neighbor), new_label] = edge_data
        new_vertices[to_symbol(new_label)] = new_label
        context(model).individual_variables[to_symbol(new_label)] = new_label
    end
    rem_vertex!(model.graph, vertex)
    interfaces = NamedTuple{Tuple(keys(new_vertices))}(values(new_vertices))
    return interfaces
end

function replace_with_edge!(model::Model, vertex::Int)
    g = model.graph
    src, dst = neighbors(g, vertex)
    edge_name = model[label_for(g, vertex)].name
    add_edge!(model, label_for(g, src), label_for(g, dst), Symbol(edge_name))
    return vertex
end

function convert_to_ffg(model::Model)
    ffg_model = deepcopy(model)
    for vertex in vertices(ffg_model.graph)
        if is_variable_node(ffg_model.graph, vertex)
            if outdegree(ffg_model.graph, vertex) > 2
                interfaces = terminate_at_neighbors!(ffg_model, vertex)
                make_node!(ffg_model, ffg_model[], equality_block, interfaces)
            end
        end
    end
    to_delete = []
    for (vertex, label) in ffg_model.graph.vertex_labels
        if is_variable_node(ffg_model.graph, vertex) &&
           outdegree(ffg_model.graph, vertex) == 2
            replace_with_edge!(ffg_model, vertex)
            push!(to_delete, vertex)
        end
    end
    for vertex in reverse(sort(to_delete))
        rem_vertex!(ffg_model.graph, vertex)
    end
    return ffg_model
end
