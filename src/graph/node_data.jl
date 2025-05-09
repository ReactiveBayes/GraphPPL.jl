"""
    NodeData(context, properties, plugins)

Data associated with a node in a probabilistic graphical model. 
The `context` field stores the context of the node. 
The `properties` field stores the properties of the node. 
The `extra` field stores additional properties of the node depending on which plugins were enabled.
"""
mutable struct NodeData
    const context    :: Context
    const properties :: Union{VariableNodeProperties, FactorNodeProperties{NodeData}}
    const extra      :: UnorderedDictionary{Symbol, Any}
end

NodeData(context, properties) = NodeData(context, properties, UnorderedDictionary{Symbol, Any}())

function Base.show(io::IO, nodedata::NodeData)
    context = getcontext(nodedata)
    properties = getproperties(nodedata)
    print(io, "NodeData in context ", shortname(context), " with properties ", properties)
    extra = getextra(nodedata)
    if !isempty(extra)
        print(io, " with extra: ")
        print(io, extra)
    end
end

getcontext(node::NodeData)    = node.context
getproperties(node::NodeData) = node.properties
getextra(node::NodeData)      = node.extra

is_constant(node::NodeData) = is_constant(getproperties(node))

"""
    hasextra(node::NodeData, key::Symbol)

Checks if `NodeData` has an extra property with the given key.
"""
hasextra(node::NodeData, key::Symbol) = haskey(node.extra, key)
"""
    getextra(node::NodeData, key::Symbol, [ default ])

Returns the extra property with the given key. Optionally, if the property does not exist, returns the default value.
"""
getextra(node::NodeData, key::Symbol) = getindex(node.extra, key)
getextra(node::NodeData, key::Symbol, default) = hasextra(node, key) ? getextra(node, key) : default

""" 
    setextra!(node::NodeData, key::Symbol, value)

Sets the extra property with the given key to the given value.
"""
setextra!(node::NodeData, key::Symbol, value) = insert!(node.extra, key, value)

"""
A compile time key to access the `extra` properties of the `NodeData` structure.
"""
struct NodeDataExtraKey{K, T} end

getkey(::NodeDataExtraKey{K, T}) where {K, T} = K

function hasextra(node::NodeData, key::NodeDataExtraKey{K}) where {K}
    return haskey(node.extra, K)
end
function getextra(node::NodeData, key::NodeDataExtraKey{K, T})::T where {K, T}
    return getindex(node.extra, K)::T
end
function getextra(node::NodeData, key::NodeDataExtraKey{K, T}, default::T)::T where {K, T}
    return hasextra(node, key) ? (getextra(node, key)::T) : default
end
function setextra!(node::NodeData, key::NodeDataExtraKey{K}, value::T) where {K, T}
    return insert!(node.extra, K, value)
end

"""
    is_factor(nodedata::NodeData)

Returns `true` if the node data is associated with a factor node, `false` otherwise.
See also: [`is_variable`](@ref),
"""
is_factor(node::NodeData) = is_factor(getproperties(node))
"""
    is_variable(nodedata::NodeData)

Returns `true` if the node data is associated with a variable node, `false` otherwise.
See also: [`is_factor`](@ref),
"""
is_variable(node::NodeData) = is_variable(getproperties(node))