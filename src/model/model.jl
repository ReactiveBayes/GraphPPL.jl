using BipartiteFactorGraphs

"""
    Model(graph::MetaGraph)

A structure representing a probabilistic graphical model. It contains a `MetaGraph` object
representing the factor graph and a `Base.RefValue{Int64}` object to keep track of the number
of nodes in the graph.

Fields:
- `graph`: A `MetaGraph` object representing the factor graph.
- `plugins`: A `PluginsCollection` object representing the plugins enabled in the model.
- `backend`: A `Backend` object representing the backend used in the model.
- `source`: A `Source` object representing the original source code of the model (typically a `String` object).
- `counter`: A `Base.RefValue{Int64}` object keeping track of the number of nodes in the graph.
"""
struct Model{G, P, B, S, C} <: AbstractModel
    graph::G
    context::C
    mapping::Dict{NodeLabel, Int}
    plugins::P
    backend::B
    source::S
    counter::Base.RefValue{Int64}
end

labels(model::Model) = Iterators.map(i -> NodeLabel(:anything, i), 1:nv(model.graph))
Base.isempty(model::Model) = iszero(nv(model.graph)) && iszero(ne(model.graph))

getplugins(model::Model) = model.plugins
getbackend(model::Model) = model.backend
getsource(model::Model) = model.source
getcounter(model::Model) = model.counter[]
setcounter!(model::Model, value) = model.counter[] = value

Graphs.savegraph(file::AbstractString, model::GraphPPL.Model) = save(file, "__model__", model)
Graphs.loadgraph(file::AbstractString, ::Type{GraphPPL.Model}) = load(file, "__model__")

NodeType(model::Model, fform::F) where {F} = NodeType(getbackend(model), fform)
NodeBehaviour(model::Model, fform::F) where {F} = NodeBehaviour(getbackend(model), fform)

function Model(graph::BipartiteFactorGraph, context::Context, plugins::PluginsCollection, backend, source)
    return Model(graph, context, Dict{NodeLabel, Int}(), plugins, backend, source, Base.RefValue(0))
end

function Model(fform::F, plugins::PluginsCollection) where {F}
    return Model(fform, plugins, default_backend(fform), nothing)
end

function Model(fform::F, plugins::PluginsCollection, backend, source) where {F}
    graph = BipartiteFactorGraph(NodeData, NodeData, EdgeLabel)
    model = Model(graph, Context(fform), plugins, backend, source)
    return model
end

Base.setindex!(model::Model, val::NodeData, key::NodeLabel) = begin
    intkey = if is_variable(val)
        BipartiteFactorGraphs.add_variable!(model.graph, val)
    elseif is_factor(val)
        BipartiteFactorGraphs.add_factor!(model.graph, val)
    else
        error("Invalid node data: $val")
    end
    @assert key.global_counter == intkey lazy"Key $key has global counter $intkey, but expected $(key.global_counter)"
    return val
end
Base.setindex!(model::Model, val::EdgeLabel, src::NodeLabel, dst::NodeLabel) = begin
    BipartiteFactorGraphs.add_edge!(model.graph, src.global_counter, dst.global_counter, val)
    return val
end
Base.getindex(model::Model) = getcontext(model)
Base.getindex(model::Model, key::NodeLabel) = begin
    id = key.global_counter
    if BipartiteFactorGraphs.is_variable(model.graph, id)
        return BipartiteFactorGraphs.get_variable_data(model.graph, id)
    else
        return BipartiteFactorGraphs.get_factor_data(model.graph, id)
    end
end
Base.getindex(model::Model, src::NodeLabel, dst::NodeLabel) =
    BipartiteFactorGraphs.get_edge_data(model.graph, src.global_counter, dst.global_counter)
Base.getindex(model::Model, keys::AbstractArray{NodeLabel}) = map(key -> model[key], keys)
Base.getindex(model::Model, keys::NTuple{N, NodeLabel}) where {N} = collect(map(key -> model[key], keys))

Base.getindex(model::Model, keys::Base.Generator) = [model[key] for key in keys]

Graphs.nv(model::Model) = Graphs.nv(model.graph)
Graphs.ne(model::Model) = Graphs.ne(model.graph)
Graphs.edges(model::Model) = Graphs.edges(model.graph)

Graphs.neighbors(model::Model, node::NodeLabel) = begin
    id = node.global_counter
    if BipartiteFactorGraphs.is_variable(model.graph, id)
        ids = BipartiteFactorGraphs.factor_neighbors(model.graph, id)
    else
        ids = BipartiteFactorGraphs.variable_neighbors(model.graph, id)
    end
    return [NodeLabel(:anything, id) for id in ids]
end
Graphs.neighbors(model::Model, nodes::AbstractArray{<:NodeLabel}) = Iterators.flatten(map(node -> Graphs.neighbors(model, node), nodes))

Graphs.edges(model::Model, node::NodeLabel) = begin
    id = node.global_counter
    if BipartiteFactorGraphs.is_variable(model.graph, id)
        ids = BipartiteFactorGraphs.factor_neighbors(model.graph, id)
    else
        ids = BipartiteFactorGraphs.variable_neighbors(model.graph, id)
    end

    return (BipartiteFactorGraphs.get_edge_data(model.graph, id, id2) for id2 in ids)
end
Graphs.edges(model::Model, nodes::AbstractArray{<:NodeLabel}) = Iterators.flatten(map(node -> Graphs.edges(model, node), nodes))

# Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData) = Graphs.edges(model, node, nodedata, getproperties(nodedata))
# Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties) =
#     map(neighbor -> neighbor[2], neighbors(properties))

# function Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::VariableNodeProperties)
#     return (model[node, dst] for dst in MetaGraphsNext.neighbor_labels(model.graph, node))
# end

Graphs.degree(model::Model, label::NodeLabel) = Graphs.degree(model.graph, label.global_counter)

function add_vertex!(model::Model, label, data)
    model[label] = data
    return true
end

function add_edge!(model::Model, src::NodeLabel, dst::NodeLabel, data)
    return BipartiteFactorGraphs.add_edge!(model.graph, src.global_counter, dst.global_counter, data)
end

function has_edge(model::Model, src::NodeLabel, dst::NodeLabel)
    return BipartiteFactorGraphs.has_edge(model.graph, src.global_counter, dst.global_counter)
end

function generate_nodelabel(model::Model, name::Symbol)
    nextcounter = setcounter!(model, getcounter(model) + 1)
    return NodeLabel(name, nextcounter)
end

"""
    getcontext(model::Model)

Retrieves the context of a model. The context of a model contains the complete hierarchy of variables and factor nodes. 
Additionally, contains all child submodels and their respective contexts. The Context supplies a mapping from symbols to `GraphPPL.NodeLabel` structures
with which the model can be queried.
"""
getcontext(model::Model) = model.context

function get_principal_submodel(model::Model)
    context = getcontext(model)
    return context
end

"""
    aliases(backend, fform)

Returns a collection of aliases for `fform` depending on the `backend`.
"""
aliases(model::Model, fform::F) where {F} = aliases(getbackend(model), fform)

factor_nodes(model::Model)   = Iterators.filter(node -> is_factor(model[node]), labels(model))
variable_nodes(model::Model) = Iterators.filter(node -> is_variable(model[node]), labels(model))

"""
A version `factor_nodes(model)` that uses a callback function to process the factor nodes.
The callback function accepts both the label and the node data.
"""
function factor_nodes(callback::F, model::Model) where {F}
    for label in labels(model)
        nodedata = model[label]
        if is_factor(nodedata)
            callback((label::NodeLabel), (nodedata::NodeData))
        end
    end
end

"""
A version `variable_nodes(model)` that uses a callback function to process the variable nodes.
The callback function accepts both the label and the node data.
"""
function variable_nodes(callback::F, model::Model) where {F}
    for label in labels(model)
        nodedata = model[label]
        if is_variable(nodedata)
            callback((label::NodeLabel), (nodedata::NodeData))
        end
    end
end

"""
    prune!(m::Model)

Remove all nodes from the model that are not connected to any other node.
"""
function prune!(m::Model)
    degrees = degree(m.graph)
    nodes_to_remove = keys(degrees)[degrees .== 0]
    nodes_to_remove = sort(nodes_to_remove, rev = true)
    rem_vertex!.(Ref(m.graph), nodes_to_remove)
end