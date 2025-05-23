"""
    EdgeDataInterface

Abstract interface for edges in a factor graph. Represents the connection
between nodes and its properties.
"""
abstract type EdgeDataInterface end

"""
    get_name(edge::E) where {E<:EdgeDataInterface}

Get the name of the edge.

# Arguments
- `edge`: The edge data to query

# Returns
The name associated with this edge
"""
function get_name(::E) where {E <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_name, E, EdgeDataInterface))
end

"""
    get_index(edge::E) where {E<:EdgeDataInterface}

Get the index of the edge.

# Arguments
- `edge`: The edge data to query

# Returns
The index associated with this edge
"""
function get_index(::E) where {E <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_index, E, EdgeDataInterface))
end

"""
    has_extra(edge::E, key) where {E<:EdgeDataInterface}

Check if the edge has an extra property with the given key.

# Arguments
- `edge`: The edge data to check
- `key`: The key to look up in the extra properties

# Returns
`true` if the extra property exists, `false` otherwise
"""
function has_extra(::E, key) where {E <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(has_extra, E, EdgeDataInterface))
end

"""
    get_extra(edge::E, key) where {E<:EdgeDataInterface}
    get_extra(edge::E, key, default) where {E<:EdgeDataInterface}

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value.

# Arguments
- `edge`: The edge data to query
- `key`: The key to look up in the extra properties
- `default`: Optional default value to return if the key doesn't exist

# Returns
The value associated with the key, or the default value if provided and the key doesn't exist
"""
function get_extra(::E, args...) where {E <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_extra, E, EdgeDataInterface))
end

"""
    set_extra!(edge::E, key, value) where {E<:EdgeDataInterface}

Set the extra property with the given key to the given value.

# Arguments
- `edge`: The edge data to modify
- `key`: The key to set in the extra properties
- `value`: The value to associate with the key
"""
function set_extra!(::E, key, value) where {E <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(set_extra!, E, EdgeDataInterface))
end

"""
    create_edge_data(::Type{T}; name, index) where {T<:EdgeDataInterface}

Create edge data with the given name and index.

# Arguments
- `::Type{T}`: The concrete type of edge data to create
- `name`: The name of the edge
- `index`: The index of the edge

# Returns
An instance of type T containing the edge data
"""
function create_edge_data(::Type{T}; name, index) where {T <: EdgeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(create_edge_data, T, EdgeDataInterface))
end