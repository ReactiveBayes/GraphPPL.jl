using Graphs
using MetaGraphsNext
import Base: put!, haskey, gensym, getindex, getproperty, setproperty!, setindex!
using GraphPlot, Compose
import Cairo


struct Model
    graph::MetaGraph
    counter::Base.RefValue{Int64}
end

struct NodeLabel
    name::Symbol
    index::Int64
end

struct NodeData
    is_variable::Bool
    name::Any
end

struct EdgeLabel
    name::Symbol
end

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

function gensym(model::Model, name::Symbol)
    increase_count(model)
    return NodeLabel(name, model.counter)
end

gensym(model::Model, name) = gensym(model::Model, Symbol(name))

to_symbol(id::NodeLabel) = Symbol(String(id.name) * "_" * string(id.index))

struct Context
    prefix::String
    contents::Dict{Symbol,Union{NodeLabel,Context}}
end


name(f::Function) = String(Symbol(f))

Context(prefix::String) = Context(prefix, Dict())
Context(parent::Context, model_name::String) = Context(parent.prefix * model_name * "_")
Context(parent::Context, model_name::Function) = Context(parent, name(model_name))
Context() = Context("")

haskey(context::Context, key::Symbol) = haskey(context.contents, key)

getindex(c::Context, key::Symbol) = c.contents[key]

context(model::Model) = model.graph[]


function pprint(str::String, indent::Int)
    print("   "^indent * str)
end

function pprint(context::Context, indent = 0)
    println("Context " * context.prefix * "{")
    for pair in context.contents
        pprint(pair, indent + 1)
    end
    pprint("} \n", indent + 1)
end

function pprint(pair::Pair{Symbol,Union{NodeLabel,Context}}, indent = 0)
    pprint(String(pair[1]) * " : ", indent)
    pprint(pair[2], indent)
end

pprint(symbol::NodeLabel) = println(String(symbol.name))


abstract type NodeType end

struct Composite <: NodeType end
struct Atomic <: NodeType end


NodeType(::Type) = Atomic()
NodeType(::Function) = Atomic()

function Base.put!(context::Context, name::Symbol, variable::Union{NodeLabel,Context})
    if haskey(context, name)
        throw(
            ErrorException(
                "Variable " *
                String(name) *
                " in Context " *
                context.prefix *
                " is duplicate.",
            ),
        )
    end
    context.contents[name] = variable
end

Base.put!(context::Context, name::NodeLabel, variable::Union{NodeLabel,Context}) =
    Base.put!(context, to_symbol(name), variable)

function create_model(interfaces...)
    model = MetaGraph(
        Graph(),
        Label = NodeLabel,
        VertexData = NodeData,
        graph_data = Context(),
        EdgeData = EdgeLabel,
    )
    model = Model(model)
    for interface in interfaces
        add_variable_node!(model, context(model), interface)
    end
    return model
end

function copy_markov_blanket_to_child_context(
    child_context::Context,
    interfaces::NamedTuple,
)
    for (child_name, parent_name) in iterator(interfaces)
        put!(child_context, child_name, parent_name)
    end
end

getorcreate!(model::Model, context::Context, edge) = edge
getorcreate!(model::Model, something) = getorcreate!(model, context(model), something)
getorcreate!(model::Model, context::Context, edge::Symbol) =
    get!(() -> add_variable_node!(model, context, edge), context.contents, edge)
getorcreate!(model::Model, context::Context, edges::Union{Tuple,AbstractArray}) =
    map((edge) -> getorcreate!(model, context, edge), edges)

function add_variable_node!(model::Model, context::Context, variable_id::Symbol)
    variable_symbol = gensym(model, variable_id)
    put!(context, variable_id, variable_symbol)
    model[variable_symbol] = NodeData(true, variable_id)
    return variable_symbol
end

function add_atomic_factor_node!(model::Model, context::Context, node_name::Symbol)
    node_id = gensym(model, Symbol(node_name))
    model[node_id] = NodeData(false, node_name)
    put!(context, node_id, node_id)
    return node_id
end

add_atomic_factor_node!(model::Model, context::Context, node_name::Real) =
    throw(MethodError("Cannot create factor node with Real argument"))
add_atomic_factor_node!(model::Model, context::Context, node_name) =
    add_atomic_factor_node!(model, context, Symbol(node_name))

function add_composite_factor_node!(
    model::Model,
    parent_context::Context,
    context::Context,
    node_name::Symbol,
)
    node_id = gensym(model, node_name)
    put!(parent_context, node_id, context)
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
    variable_nodes::Union{AbstractArray{NodeLabel},Tuple},
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
make_node!(model::Model, node_name, interfaces::NamedTuple) =
    make_node!(model, context(model), node_name, interfaces)


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

    current_terminal = add_variable_node!(model, context, :out)
    first_input = context[keys(interfaces)[1]]
    second_input = context[keys(interfaces)[2]]
    make_node!(
        model,
        context,
        equality_node,
        (in1 = first_input, in2 = second_input, in3 = current_terminal),
    )
    for i in range(3, length(interfaces) - 2)
        new_terminal = add_variable_node!(model, context, gensym(:out))
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
    put!(parent_context, node_id, context)

end

function plot_graph(g::MetaGraph; name = "tmp.png")
    node_labels =
        [label[2].name for label in sort(collect(g.vertex_labels), by = x -> x[1])]
    draw(PNG(name, 16cm, 16cm), gplot(g, nodelabel = node_labels))
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
        put!(context(model), new_label, new_label)
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
