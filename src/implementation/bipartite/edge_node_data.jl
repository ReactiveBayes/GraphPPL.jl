"""
    EdgeNodeData

A concrete implementation of `EdgeDataInterface` that stores data for an edge in the factor graph.

# Fields
- `name::Symbol`: The name of the edge
- `index::Any = nothing`: The index of the edge
- `extras::Dict{Symbol, Any} = Dict{Symbol, Any}()`: Dictionary for storing additional properties
"""
@kwdef struct EdgeNodeData <: EdgeDataInterface
    name::Symbol
    index::Any = nothing
    extras::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

# Interface implementation
get_name(edge::EdgeNodeData) = edge.name
get_index(edge::EdgeNodeData) = edge.index

"""
    has_extra(edge::EdgeNodeData, key::Symbol)

Check if the edge has an extra property with the given key.
"""
function has_extra(edge::EdgeNodeData, key::Symbol)
    return haskey(edge.extras, key)
end

"""
    has_extra(edge::EdgeNodeData, key::CompileTimeDictionaryKey)

Check if the edge has an extra property with the given key.
"""
function has_extra(edge::EdgeNodeData, key::CompileTimeDictionaryKey{K, T}) where {K, T}
    return haskey(edge.extras, get_key(key))
end

"""
    get_extra(edge::EdgeNodeData, key::Symbol)

Get the extra property with the given key.
"""
function get_extra(edge::EdgeNodeData, key::Symbol)
    return edge.extras[key]
end

"""
    get_extra(edge::EdgeNodeData, key::CompileTimeDictionaryKey)

Get the extra property with the given key.
"""
function get_extra(edge::EdgeNodeData, key::CompileTimeDictionaryKey{K, T}) where {K, T}
    return convert(T, edge.extras[get_key(key)])::T
end

"""
    get_extra(edge::EdgeNodeData, key::Symbol, default)

Get the extra property with the given key. If the property does not exist, returns the default value.
"""
function get_extra(edge::EdgeNodeData, key::Symbol, default)
    return get(edge.extras, key, default)
end

"""
    get_extra(edge::EdgeNodeData, key::CompileTimeDictionaryKey, default)

Get the extra property with the given key. If the property does not exist, returns the default value.
"""
function get_extra(edge::EdgeNodeData, key::CompileTimeDictionaryKey{K, T}, default) where {K, T}
    return convert(T, get(edge.extras, get_key(key), default))::T
end

"""
    set_extra!(edge::EdgeNodeData, key::Symbol, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(edge::EdgeNodeData, key::Symbol, value)
    edge.extras[key] = value
    return value
end

"""
    set_extra!(edge::EdgeNodeData, key::CompileTimeDictionaryKey, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(edge::EdgeNodeData, key::CompileTimeDictionaryKey{K, T}, value::T) where {K, T}
    edge.extras[get_key(key)] = value
    return value
end

"""
    create_edge_data(::Type{EdgeNodeData}; name::Symbol, index::Any = nothing)

Create a new edge data of type `EdgeNodeData` with the given parameters.
"""
function create_edge_data(::Type{EdgeNodeData}; name::Symbol, index::Any = nothing)
    return EdgeNodeData(name = name, index = index)
end 