"""
    VariableNodeData

A concrete implementation of `VariableNodeDataInterface` that stores data for a variable node.

# Fields
- `name::Symbol`: The name of the variable
- `index::Any = nothing`: The index of the variable
- `link::Any = nothing`: The link to other nodes or components
- `kind::UInt8 = VariableNodeKind.Unspecified`: The kind/type of variable
- `value::Any = nothing`: The value of the variable
- `extras::Dict{Symbol, Any} = Dict{Symbol, Any}()`: Dictionary for storing additional properties
"""
@kwdef struct VariableNodeData <: VariableNodeDataInterface
    name::Symbol
    index::Any = nothing
    link::Any = nothing
    kind::UInt8 = VariableNodeKind.Unspecified
    value::Any = nothing
    extras::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

# Interface implementation
get_name(vnd::VariableNodeData) = vnd.name
get_index(vnd::VariableNodeData) = vnd.index
get_link(vnd::VariableNodeData) = vnd.link
get_kind(vnd::VariableNodeData) = vnd.kind
get_value(vnd::VariableNodeData) = vnd.value

"""
    has_extra(variable_data::VariableNodeData, key::Symbol)

Check if the variable node data has an extra property with the given key.
"""
function has_extra(variable_data::VariableNodeData, key::Symbol)
    return haskey(variable_data.extras, key)
end

"""
    has_extra(variable_data::VariableNodeData, key::CompileTimeDictionaryKey)

Check if the variable node data has an extra property with the given key.
"""
function has_extra(variable_data::VariableNodeData, key::CompileTimeDictionaryKey{K, T}) where {K, T}
    return haskey(variable_data.extras, get_key(key))
end

"""
    get_extra(variable_data::VariableNodeData, key::Symbol)

Get the extra property with the given key.
"""
function get_extra(variable_data::VariableNodeData, key::Symbol)
    return variable_data.extras[key]
end

"""
    get_extra(variable_data::VariableNodeData, key::CompileTimeDictionaryKey)

Get the extra property with the given key.
"""
function get_extra(variable_data::VariableNodeData, key::CompileTimeDictionaryKey{K, T}) where {K, T}
    return convert(T, variable_data.extras[get_key(key)])::T
end

"""
    get_extra(variable_data::VariableNodeData, key::Symbol, default)

Get the extra property with the given key. If the property does not exist, returns the default value.
"""
function get_extra(variable_data::VariableNodeData, key::Symbol, default)
    return get(variable_data.extras, key, default)
end

"""
    get_extra(variable_data::VariableNodeData, key::CompileTimeDictionaryKey, default)

Get the extra property with the given key. If the property does not exist, returns the default value.
"""
function get_extra(variable_data::VariableNodeData, key::CompileTimeDictionaryKey{K, T}, default) where {K, T}
    return convert(T, get(variable_data.extras, get_key(key), default))::T
end

"""
    set_extra!(variable_data::VariableNodeData, key::Symbol, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(variable_data::VariableNodeData, key::Symbol, value)
    variable_data.extras[key] = value
    return value
end

"""
    set_extra!(variable_data::VariableNodeData, key::Symbol, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(variable_data::VariableNodeData, key::CompileTimeDictionaryKey{K, T}, value::T) where {K, T}
    variable_data.extras[get_key(key)] = value
    return value
end

"""
    create_variable_data(::Type{VariableNodeData}; name::Symbol, index::Any, kind::UInt8 = VariableNodeKind.Unspecified, link::Any = nothing, value::Any = nothing)

Create a new variable node data of type `VariableNodeData` with the given parameters.
"""
function create_variable_data(
    ::Type{VariableNodeData};
    name::Symbol,
    index::Any = nothing,
    kind::UInt8 = VariableNodeKind.Unspecified,
    link::Any = nothing,
    value::Any = nothing
)
    return VariableNodeData(name = name, index = index, kind = kind, link = link, value = value)
end
