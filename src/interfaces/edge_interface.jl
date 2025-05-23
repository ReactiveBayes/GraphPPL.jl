"""
    EdgeInterface

Abstract interface for edges in a factor graph. Represents the connection
between nodes and its properties.
"""
abstract type EdgeInterface end

"""
    get_name(edge::EdgeInterface)

Get the name of the edge.
"""
function get_name end

"""
    get_index(edge::EdgeInterface)

Get the index of the edge.
"""
function get_index end

"""
    has_extra(edge::EdgeInterface, key::Symbol)
    has_extra(edge::EdgeInterface, key::NodeDataExtraKey)

Check if the edge has an extra property with the given key.
"""
function has_extra(edge::E, key) where {E <: EdgeInterface}
    throw(GraphPPLInterfaceNotImplemented(has_extra, E, EdgeInterface))
end

"""
    get_extra(edge::EdgeInterface, key)
    get_extra(edge::EdgeInterface, key, default)

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value. The NodeDataExtraKey versions provide type safety at compile time.
"""
function get_extra(edge::E, args...) where {E <: EdgeInterface}
    throw(GraphPPLInterfaceNotImplemented(get_extra, E, EdgeInterface))
end

"""
    set_extra!(edge::EdgeInterface, key::Symbol, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(edge::E, key, value) where {E <: EdgeInterface}
    throw(GraphPPLInterfaceNotImplemented(set_extra!, E, EdgeInterface))
end

"""
    create_edge_data(::Type{T}, name, index)

Create edge data for the given model, name, and index.

# Arguments
- `model`: The factor graph model interface instance
- `name`: The name of the edge
- `index`: The index of the edge

# Returns
- An instance of edge data that implements `EdgeDataInterface`
"""
function create_edge_data(::Type{T}, name, index) where {T <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(create_edge_data, T, EdgeDataInterface))
end