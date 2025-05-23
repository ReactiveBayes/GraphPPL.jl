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
struct Model{G, P, B, S} <: FactorGraphModelInterface
    graph::G
    plugins::P
    backend::B
    source::S
    counter::Base.RefValue{Int64}
end

get_context(model::Model) = model.graph[]

Graphs.nv(model::Model) = Graphs.nv(model.graph)
Graphs.ne(model::Model) = Graphs.ne(model.graph)

get_plugins(model::Model) = model.plugins
get_backend(model::Model) = model.backend
get_source(model::Model) = model.source
get_counter(model::Model) = model.counter[]
set_counter!(model::Model, value) = model.counter[] = value

save_model(file::AbstractString, model::GraphPPL.Model) = save(file, "__model__", model)
load_model(file::AbstractString, ::Type{GraphPPL.Model}) = load(file, "__model__")

get_node_type(model::Model, fform::F) where {F} = get_node_type(get_backend(model), fform)
NodeBehaviour(model::Model, fform::F) where {F} = NodeBehaviour(get_backend(model), fform)

function Model(graph::MetaGraph, plugins::PluginsCollection, backend, source)
    return Model(graph, plugins, backend, source, Base.RefValue(0))
end

function Model(fform::F, plugins::PluginsCollection) where {F}
    return Model(fform, plugins, default_backend(fform), nothing)
end

function Model(fform::F, plugins::PluginsCollection, backend, source) where {F}
    label_type = NodeLabel
    edge_data_type = EdgeLabel
    vertex_data_type = NodeData
    graph = MetaGraph(Graph(), label_type, vertex_data_type, edge_data_type, Context(fform))
    model = Model(graph, plugins, backend, source)
    return model
end

Base.setindex!(model::Model, val::NodeData, key::NodeLabel) = Base.setindex!(model.graph, val, key)
Base.setindex!(model::Model, val::EdgeLabel, src::NodeLabel, dst::NodeLabel) = Base.setindex!(model.graph, val, src, dst)
Base.getindex(model::Model) = Base.getindex(model.graph)
Base.getindex(model::Model, key::NodeLabel) = Base.getindex(model.graph, key)
Base.getindex(model::Model, src::NodeLabel, dst::NodeLabel) = Base.getindex(model.graph, src, dst)
Base.getindex(model::Model, keys::AbstractArray{NodeLabel}) = map(key -> model[key], keys)
Base.getindex(model::Model, keys::NTuple{N, NodeLabel}) where {N} = collect(map(key -> model[key], keys))

Base.getindex(model::Model, keys::Base.Generator) = [model[key] for key in keys]

Graphs.edges(model::Model) = Graphs.edges(model.graph)

Graphs.neighbors(model::Model, node::NodeLabel)                   = Graphs.neighbors(model, node, model[node])
Graphs.neighbors(model::Model, nodes::AbstractArray{<:NodeLabel}) = Iterators.flatten(map(node -> Graphs.neighbors(model, node), nodes))

Graphs.neighbors(model::Model, node::NodeLabel, nodedata::NodeData)                                     = Graphs.neighbors(model, node, nodedata, getproperties(nodedata))
Graphs.neighbors(model::Model, node::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties)   = map(neighbor -> neighbor[1], neighbors(properties))
Graphs.neighbors(model::Model, node::NodeLabel, nodedata::NodeData, properties::VariableNodeProperties) = MetaGraphsNext.neighbor_labels(model.graph, node)

Graphs.edges(model::Model, node::NodeLabel) = Graphs.edges(model, node, model[node])
Graphs.edges(model::Model, nodes::AbstractArray{<:NodeLabel}) = Iterators.flatten(map(node -> Graphs.edges(model, node), nodes))

Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData) = Graphs.edges(model, node, nodedata, getproperties(nodedata))
Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties) =
    map(neighbor -> neighbor[2], neighbors(properties))

function Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::VariableNodeProperties)
    return (model[node, dst] for dst in MetaGraphsNext.neighbor_labels(model.graph, node))
end

Graphs.degree(model::Model, label::NodeLabel) = Graphs.degree(model.graph, MetaGraphsNext.code_for(model.graph, label))

function add_vertex!(model::Model, label, data)
    # This is an unsafe procedure that implements behaviour from `MetaGraphsNext`. 
    code = nv(model) + 1
    model.graph.vertex_labels[code] = label
    model.graph.vertex_properties[label] = (code, data)
    Graphs.add_vertex!(model.graph.graph)
end

function add_edge!(model::Model, src, dst, data)
    # This is an unsafe procedure that implements behaviour from `MetaGraphsNext`. 
    code_src, code_dst = MetaGraphsNext.code_for(model.graph, src), MetaGraphsNext.code_for(model.graph, dst)
    model.graph.edge_data[(src, dst)] = data
    return Graphs.add_edge!(model.graph.graph, code_src, code_dst)
end

function has_edge(model::Model, src, dst)
    code_src, code_dst = MetaGraphsNext.code_for(model.graph, src), MetaGraphsNext.code_for(model.graph, dst)
    return Graphs.has_edge(model.graph.graph, code_src, code_dst)
end

function generate_node_label(model::Model, name::Symbol)
    next_counter = set_counter!(model, get_counter(model) + 1)
    return NodeLabel(name, next_counter)
end

"""
    get_context(model::Model)

Retrieves the context of a model. The context of a model contains the complete hierarchy of variables and factor nodes. 
Additionally, contains all child submodels and their respective contexts. The Context supplies a mapping from symbols to `GraphPPL.NodeLabel` structures
with which the model can be queried.
"""
get_context(model::Model) = model[]

function get_principal_submodel(model::Model)
    context = get_context(model)
    return context
end

"""
    aliases(backend, fform)

Returns a collection of aliases for `fform` depending on the `backend`.
"""
aliases(model::Model, fform::F) where {F} = aliases(get_backend(model), fform)

get_factors(model::Model) = Iterators.filter(node -> is_factor(model[node]), labels(model))
get_variables(model::Model) = Iterators.filter(node -> is_variable(model[node]), labels(model))

"""
A version `get_factors(model)` that uses a callback function to process the factor nodes.
The callback function accepts both the label and the node data.
"""
function get_factors(callback::F, model::Model) where {F}
    for label in labels(model)
        nodedata = model[label]
        if is_factor(nodedata)
            callback((label::NodeLabel), (nodedata::NodeData))
        end
    end
end

"""
A version `get_variables(model)` that uses a callback function to process the variable nodes.
The callback function accepts both the label and the node data.
"""
function get_variables(callback::F, model::Model) where {F}
    for label in labels(model)
        nodedata = model[label]
        if is_variable(nodedata)
            callback((label::NodeLabel), (nodedata::NodeData))
        end
    end
end
