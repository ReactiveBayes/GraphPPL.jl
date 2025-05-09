"""
    VariableNodeDataInterface

Abstract interface for variable node data in a factor graph. Contains the actual data stored
for a variable node in the model. Models can implement specific types that extend this interface.
"""
abstract type VariableNodeDataInterface end

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
    hasextra(variable_data::V, key::Symbol) where {V<:VariableNodeDataInterface}
    hasextra(variable_data::V, key::NodeDataExtraKey) where {V<:VariableNodeDataInterface}

Check if the variable node data has an extra property with the given key.
"""
function has_extra(variable_data::V, key) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(has_extra, V, VariableNodeDataInterface))
end

"""
    get_extra(variable_data::V) where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key::Symbol) where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key::Symbol, default) where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key::NodeDataExtraKey{K,T})::T where {V<:VariableNodeDataInterface}
    get_extra(variable_data::V, key::NodeDataExtraKey{K,T}, default::T)::T where {V<:VariableNodeDataInterface}

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value. The NodeDataExtraKey versions provide type safety at compile time.
"""
function get_extra(variable_data::V, args...) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_extra, V, VariableNodeDataInterface))
end

"""
    set_extra!(variable_data::V, key::Symbol, value) where {V<:VariableNodeDataInterface}
    set_extra!(variable_data::V, key::NodeDataExtraKey{K,T}, value::T) where {V<:VariableNodeDataInterface}

Set the extra property with the given key to the given value.
The NodeDataExtraKey version provides type safety at compile time.
"""
function set_extra!(variable_data::V, key, value) where {V <: VariableNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(set_extra!, V, VariableNodeDataInterface))
end
