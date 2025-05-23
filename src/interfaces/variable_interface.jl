"""
    VariableNodeDataInterface

Abstract interface for variable node data in a factor graph. Contains the actual data stored
for a variable node in the model. Models can implement specific types that extend this interface.
"""
abstract type VariableNodeDataInterface end

module VariableNodeKind
const Unspecified::UInt8 = UInt8(0x00)
const Random::UInt8 = UInt8(0x01)
const Data::UInt8 = UInt8(0x02)
const Constant::UInt8 = UInt8(0x03)
const Anonymous::UInt8 = UInt8(0x04)
const Unknown::UInt8 = UInt8(0x05)
end

"""
    get_name(variable_data::V) where {V<:VariableNodeDataInterface}

Get the name of the variable node data.
"""
function get_name(::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_name, V, VariableNodeDataInterface))
end

"""
    get_index(variable_data::V) where {V<:VariableNodeDataInterface}

Get the index of the variable node data.
"""
function get_index(::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_index, V, VariableNodeDataInterface))
end

"""
    get_link(variable_data::V) where {V<:VariableNodeDataInterface}

Get the link of the variable node data.
"""
function get_link(::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_link, V, VariableNodeDataInterface))
end

"""
    get_kind(variable_data::V) where {V<:VariableNodeDataInterface}

Get the kind of the variable node data. Must return a value from the `VariableNodeKind` module.
"""
function get_kind(::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_kind, V, VariableNodeDataInterface))
end

"""
    get_value(variable_data::V) where {V<:VariableNodeDataInterface}

Get the value of the variable node data.
"""
function get_value(::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_value, V, VariableNodeDataInterface))
end

"""
    is_kind(variable_data::V, kind::UInt8) where {V <: VariableNodeDataInterface}

Check if the variable node data is of the given kind.
"""
function is_kind(variable_data::V, kind::UInt8) where {V <: VariableNodeDataInterface}
    return get_kind(variable_data) === kind
end

"""
    is_random(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is random.
"""
function is_random(variable_data::V) where {V <: VariableNodeDataInterface}
    return is_kind(variable_data, VariableNodeKind.Random)
end

"""
    is_data(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is data.
"""
function is_data(variable_data::V) where {V <: VariableNodeDataInterface}
    return is_kind(variable_data, VariableNodeKind.Data)
end

"""
    is_constant(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is constant.
"""
function is_constant(variable_data::V) where {V <: VariableNodeDataInterface}
    return is_kind(variable_data, VariableNodeKind.Constant)
end

"""
    is_anonymous(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is anonymous.
"""
function is_anonymous(variable_data::V) where {V <: VariableNodeDataInterface}
    return is_kind(variable_data, VariableNodeKind.Anonymous)
end

"""
    hasextra(variable_data::V, key) where {V<:VariableNodeDataInterface}

Check if the variable node data has an extra property with the given key.
"""
function has_extra(::V, key) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(has_extra, V, VariableNodeDataInterface))
end

"""
    get_extra(variable_data::V, key) where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key, default) where {V<:VariableNodeDataInterface}

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value.
"""
function get_extra(::V, args...) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_extra, V, VariableNodeDataInterface))
end

"""
    set_extra!(variable_data::V, key, value) where {V<:VariableNodeDataInterface}

Set the extra property with the given key to the given value.
"""
function set_extra!(::V, key, value) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(set_extra!, V, VariableNodeDataInterface))
end

"""
    create_variable_data(::Type{T}; name::Symbol, index::Any, kind::UInt8 = VariableNodeKind.Unspecified, link::Any = nothing, value::Any = nothing) where {T<:VariableNodeDataInterface}

Template constructor for variable node data. Implementations can specialize on T to provide
different construction logic for different node data types.

# Arguments
- `::Type{T}`: The concrete type of node data to create
- `name::Symbol`: The name of the variable
- `index::Any`: The index associated with the variable (nothing for non-indexed)
- `kind::UInt8`: The kind of variable (see VariableNodeKind module)
- `link::Any`: Optional link to other nodes/components
- `value::Any`: Optional pre-assigned value

# Returns
An instance of type T containing the variable node data
"""
function create_variable_data(
    ::Type{T}; name::Symbol, index::Any, kind::Symbol = VariableNodeKind.Unspecified, link::Any = nothing, value::Any = nothing
) where {T <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(create_variable_data, T, VariableNodeDataInterface))
end