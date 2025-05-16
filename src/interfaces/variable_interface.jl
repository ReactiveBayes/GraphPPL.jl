"""
    VariableNodeDataInterface

Abstract interface for variable node data in a factor graph. Contains the actual data stored
for a variable node in the model. Models can implement specific types that extend this interface.
"""
abstract type VariableNodeDataInterface end

"""
    create_variable_data(::Type{T}, name::Symbol, index::Any, kind::Symbol, link::Any, value::Any, context::Any, metadata::Any=nothing) where {T<:VariableNodeDataInterface}

Template constructor for variable node data. Implementations can specialize on T to provide
different construction logic for different node data types.

# Arguments
- `::Type{T}`: The concrete type of node data to create
- `name::Symbol`: The name of the variable
- `index::Any`: The index associated with the variable (nothing for non-indexed)
- `kind::Symbol`: The kind of variable (e.g. :random, :data, :constant)
- `link::Any`: Optional link to other nodes/components
- `value::Any`: Optional pre-assigned value
- `context::Any`: The context in which this variable exists
- `metadata::Any`: Optional additional metadata for extensions

# Returns
An instance of type T containing the variable node data
"""
function create_variable_data(
    ::Type{T}, name::Symbol, index::Any, kind::Symbol, link::Any, value::Any, context::Any, metadata::Any = nothing
) where {T <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(create_variable_data, T, VariableNodeDataInterface))
end

"""
    get_name(variable_data::V) where {V<:VariableNodeDataInterface}

Get the name of the variable node data.
"""
function get_name(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_name, V, VariableNodeDataInterface))
end

"""
    get_index(variable_data::V) where {V<:VariableNodeDataInterface}

Get the index of the variable node data.
"""
function get_index(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_index, V, VariableNodeDataInterface))
end

"""
    get_link(variable_data::V) where {V<:VariableNodeDataInterface}

Get the link of the variable node data.
"""
function get_link(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_link, V, VariableNodeDataInterface))
end

"""
    get_kind(variable_data::V) where {V<:VariableNodeDataInterface}

Get the kind of the variable node data.
"""
function get_kind(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_kind, V, VariableNodeDataInterface))
end

"""
    get_value(variable_data::V) where {V<:VariableNodeDataInterface}

Get the value of the variable node data.
"""
function get_value(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_value, V, VariableNodeDataInterface))
end

"""
    is_random(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is random.
"""
function is_random(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(is_random, V, VariableNodeDataInterface))
end

"""
    is_data(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is data.
"""
function is_data(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(is_data, V, VariableNodeDataInterface))
end

"""
    is_constant(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is constant.
"""
function is_constant(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(is_constant, V, VariableNodeDataInterface))
end

"""
    is_anonymous(variable_data::V) where {V<:VariableNodeDataInterface}

Check if the variable node data is anonymous.
"""
function is_anonymous(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(is_anonymous, V, VariableNodeDataInterface))
end

"""

    get_context(variable_data::V) where {V<:VariableNodeDataInterface}

Get the context associated with the variable node data.
"""
function get_context(variable_data::V) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_context, V, VariableNodeDataInterface))
end

"""
    hasextra(variable_data::V, key) where {V<:VariableNodeDataInterface}

Check if the variable node data has an extra property with the given key.
"""
function has_extra(variable_data::V, key) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(has_extra, V, VariableNodeDataInterface))
end

"""
    get_extra(variable_data::V) where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key) where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key, default) where {V<:VariableNodeDataInterface}

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value.
"""
function get_extra(variable_data::V, args...) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_extra, V, VariableNodeDataInterface))
end

"""
    set_extra!(variable_data::V, key, value) where {V<:VariableNodeDataInterface}

Set the extra property with the given key to the given value.
"""
function set_extra!(variable_data::V, key, value) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(set_extra!, V, VariableNodeDataInterface))
end
