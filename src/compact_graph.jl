"""
    CompactGraphPlugin()

Opt in to indexed graph connectivity and columnar node metadata during model
construction. This does not select an inference algorithm. The default storage
and existing reactive inference are unchanged when this plugin is absent.
"""
struct CompactGraphPlugin end

struct CompactStoragePluginType <: AbstractPluginTraitType end
plugin_type(::CompactGraphPlugin) = CompactStoragePluginType()

# Insertion-ordered, flat linked adjacency. Two arcs reference each edge label.
# There is no dictionary per vertex or edge and no vector per adjacency list.
struct CompactGraph
    context::Context
    node_labels::Vector{NodeLabel}
    node_data::Vector{NodeData}
    heads::Vector{UInt32}
    tails::Vector{UInt32}
    degrees::Vector{UInt32}
    destinations::Vector{UInt32}
    next_arc::Vector{UInt32}
    arc_edges::Vector{UInt32}
    edge_labels::Vector{EdgeLabel}
    edge_label_pool::Dict{Tuple{Symbol, Union{Int, Nothing}}, EdgeLabel}
    extras::CompactExtraColumns
end

CompactGraph(fform) = CompactGraph(
    Context(fform), NodeLabel[], NodeData[], UInt32[], UInt32[], UInt32[],
    UInt32[], UInt32[], UInt32[], EdgeLabel[], Dict{Tuple{Symbol, Union{Int, Nothing}}, EdgeLabel}(), CompactExtraColumns(),
)

Model(graph::CompactGraph, plugins::PluginsCollection, backend, source) =
    Model(graph, plugins, backend, source, Ref(0))

function create_graph_storage(fform, plugins::PluginsCollection)
    if any(plugin -> plugin isa CompactGraphPlugin, plugins)
        return CompactGraph(fform)
    end
    return MetaGraph(Graph(), NodeLabel, NodeData, EdgeLabel, Context(fform))
end

function new_node_data(model::Model{CompactGraph}, label::NodeLabel, context, properties)
    if properties isa FactorNodeProperties
        isempty(properties.neighbors) || throw(ArgumentError("Compact factor storage requires edges to be registered through add_edge!"))
        properties = FactorNodeProperties{NodeData}(properties.fform, CompactFactorNeighbors{NodeData}(model.graph, label.global_counter))
    end
    return NodeData(context, properties, CompactNodeExtras(model.graph.extras, label.global_counter))
end

Base.IndexStyle(::Type{<:CompactFactorNeighbors}) = IndexLinear()
Base.size(neighbors::CompactFactorNeighbors) = (neighbors.node <= length(neighbors.graph.degrees) ? Int(neighbors.graph.degrees[neighbors.node]) : 0,)
function compact_factor_neighbor(neighbors::CompactFactorNeighbors{D}, arc) where {D}
    graph = neighbors.graph
    other = graph.destinations[arc]
    return (graph.node_labels[other], graph.edge_labels[graph.arc_edges[arc]], graph.node_data[other])::Tuple{NodeLabel, EdgeLabel, D}
end
function Base.getindex(neighbors::CompactFactorNeighbors, i::Int)
    @boundscheck checkbounds(neighbors, i)
    graph = neighbors.graph
    arc = graph.heads[neighbors.node]
    # Atomic model expansion inserts a factor's arcs consecutively, with one
    # reverse arc between each pair. Keep a correct fallback for extension code
    # that adds edges to an older factor later.
    if graph.tails[neighbors.node] - arc == 2 * (length(neighbors) - 1)
        arc += 2 * (i - 1)
    else
        for _ in 2:i
            arc = graph.next_arc[arc]
        end
    end
    return compact_factor_neighbor(neighbors, arc)
end
Base.iterate(neighbors::CompactFactorNeighbors) = isempty(neighbors) ? nothing : iterate(neighbors, neighbors.graph.heads[neighbors.node])
function Base.iterate(neighbors::CompactFactorNeighbors, arc::UInt32)
    iszero(arc) && return nothing
    return compact_factor_neighbor(neighbors, arc), neighbors.graph.next_arc[arc]
end

Base.getindex(graph::CompactGraph) = graph.context
MetaGraphsNext.labels(graph::CompactGraph) = graph.node_labels
Graphs.nv(graph::CompactGraph) = length(graph.node_labels)
Graphs.ne(graph::CompactGraph) = length(graph.edge_labels)
Graphs.degree(graph::CompactGraph, index::Integer) = Int(graph.degrees[index])
Graphs.degree(graph::CompactGraph) = Int.(graph.degrees)

function MetaGraphsNext.code_for(graph::CompactGraph, label::NodeLabel)
    index = label.global_counter
    if !(1 <= index <= length(graph.node_labels)) || graph.node_labels[index] != label
        throw(KeyError(label))
    end
    return index
end

Base.getindex(graph::CompactGraph, label::NodeLabel) = graph.node_data[MetaGraphsNext.code_for(graph, label)]
Base.setindex!(graph::CompactGraph, data::NodeData, label::NodeLabel) = (graph.node_data[MetaGraphsNext.code_for(graph, label)] = data)

function add_vertex!(model::Model{CompactGraph}, label::NodeLabel, data::NodeData)
    graph = model.graph
    index = length(graph.node_labels) + 1
    index <= typemax(UInt32) || throw(OverflowError("Compact graph exceeds UInt32 node capacity"))
    label.global_counter == index || throw(ArgumentError("Compact storage requires consecutive node IDs; relabeling plugins need a compact adapter"))
    push!(graph.node_labels, label)
    push!(graph.node_data, data)
    push!(graph.heads, 0)
    push!(graph.tails, 0)
    push!(graph.degrees, 0)
    return true
end

struct CompactNeighborLabels
    graph::CompactGraph
    node::Int
end

Base.eltype(::Type{CompactNeighborLabels}) = NodeLabel
Base.length(neighbors::CompactNeighborLabels) = Int(neighbors.graph.degrees[neighbors.node])
Base.iterate(neighbors::CompactNeighborLabels) = iterate(neighbors, neighbors.graph.heads[neighbors.node])
function Base.iterate(neighbors::CompactNeighborLabels, arc::UInt32)
    iszero(arc) && return nothing
    graph = neighbors.graph
    return graph.node_labels[graph.destinations[arc]], graph.next_arc[arc]
end

MetaGraphsNext.neighbor_labels(graph::CompactGraph, label::NodeLabel) = CompactNeighborLabels(graph, MetaGraphsNext.code_for(graph, label))

# Scan the smaller endpoint. Scanning a high-degree variable while repeatedly
# adding leaf factors would otherwise make model construction quadratic.
function compact_find_arc(graph::CompactGraph, src::Integer, dst::Integer)
    if graph.degrees[src] > graph.degrees[dst]
        src, dst = dst, src
    end
    arc = graph.heads[src]
    while !iszero(arc)
        graph.destinations[arc] == dst && return arc
        arc = graph.next_arc[arc]
    end
    return UInt32(0)
end

function has_edge(model::Model{CompactGraph}, src::NodeLabel, dst::NodeLabel)
    graph = model.graph
    return !iszero(compact_find_arc(graph, MetaGraphsNext.code_for(graph, src), MetaGraphsNext.code_for(graph, dst)))
end

function compact_push_arc!(graph::CompactGraph, src, dst, edge)
    arc = length(graph.destinations) + 1
    arc <= typemax(UInt32) || throw(OverflowError("Compact graph exceeds UInt32 arc capacity"))
    push!(graph.destinations, dst)
    push!(graph.next_arc, 0)
    push!(graph.arc_edges, edge)
    if iszero(graph.heads[src])
        graph.heads[src] = arc
    else
        graph.next_arc[graph.tails[src]] = arc
    end
    graph.tails[src] = arc
    graph.degrees[src] += 1
    return nothing
end

function add_edge!(model::Model{CompactGraph}, src::NodeLabel, dst::NodeLabel, data::EdgeLabel)
    graph = model.graph
    s, d = MetaGraphsNext.code_for(graph, src), MetaGraphsNext.code_for(graph, dst)
    iszero(compact_find_arc(graph, s, d)) || return false
    length(graph.destinations) <= typemax(UInt32) - 2 || throw(OverflowError("Compact graph exceeds UInt32 arc capacity"))
    # EdgeLabel has only const fields. Sharing equal interface labels is safe,
    # while millions of identical labels would otherwise be separate objects.
    push!(graph.edge_labels, compact_intern_edge_label!(graph, data))
    edge = length(graph.edge_labels)
    compact_push_arc!(graph, s, d, edge)
    compact_push_arc!(graph, d, s, edge)
    return true
end

compact_intern_edge_label!(graph::CompactGraph, data::EdgeLabel) = get!(graph.edge_label_pool, (data.name, data.index), data)

function Base.getindex(graph::CompactGraph, src::NodeLabel, dst::NodeLabel)
    arc = compact_find_arc(graph, MetaGraphsNext.code_for(graph, src), MetaGraphsNext.code_for(graph, dst))
    iszero(arc) && throw(KeyError((src, dst)))
    return graph.edge_labels[graph.arc_edges[arc]]
end

function Base.setindex!(graph::CompactGraph, data::EdgeLabel, src::NodeLabel, dst::NodeLabel)
    arc = compact_find_arc(graph, MetaGraphsNext.code_for(graph, src), MetaGraphsNext.code_for(graph, dst))
    iszero(arc) && throw(KeyError((src, dst)))
    graph.edge_labels[graph.arc_edges[arc]] = compact_intern_edge_label!(graph, data)
    return data
end

function Graphs.edges(graph::CompactGraph)
    return (Graphs.Edge(i, Int(graph.destinations[a])) for i in eachindex(graph.node_labels)
        for a in CompactArcIndices(graph, i) if i < graph.destinations[a])
end

struct CompactArcIndices
    graph::CompactGraph
    node::Int
end
Base.eltype(::Type{CompactArcIndices}) = UInt32
Base.length(arcs::CompactArcIndices) = Int(arcs.graph.degrees[arcs.node])
Base.iterate(arcs::CompactArcIndices) = iterate(arcs, arcs.graph.heads[arcs.node])
Base.iterate(arcs::CompactArcIndices, arc::UInt32) = iszero(arc) ? nothing : (arc, arcs.graph.next_arc[arc])

function prune!(model::Model{CompactGraph})
    throw(ArgumentError("prune! is not supported for compact graphs with stable node IDs"))
end

"Release construction-only spare vector capacity without changing node IDs."
function compact_shrink!(model::Model{CompactGraph})
    graph = model.graph
    for field in fieldnames(CompactGraph)
        value = getfield(graph, field)
        value isa Vector && sizehint!(value, length(value); shrink = true)
    end
    for column in values(graph.extras.columns)
        sizehint!(column.values, length(column); shrink = true)
        sizehint!(column.present, length(column); shrink = true)
    end
    empty!(graph.extras.interned)
    return model
end
