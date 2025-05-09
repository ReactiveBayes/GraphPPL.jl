"""
    VariableNodeDataInterface

Abstract interface for variable node data in a factor graph. Contains the actual data stored
for a variable node in the model. Models can implement specific types that extend this interface.
"""
abstract type VariableNodeDataInterface end

"""
    get_name(variable_data::VariableNodeDataInterface)

Get the name of the variable node data.
"""
function get_name(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_name, typeof(variable_data), VariableNodeDataInterface))
end

"""
    get_index(variable_data::VariableNodeDataInterface)

Get the index of the variable node data.
"""
function get_index(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_index, typeof(variable_data), VariableNodeDataInterface))
end

"""
    get_link(variable_data::VariableNodeDataInterface)

Get the link of the variable node data.
"""
function get_link(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_link, typeof(variable_data), VariableNodeDataInterface))
end

"""
    get_kind(variable_data::VariableNodeDataInterface)

Get the kind of the variable node data.
"""
function get_kind(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_kind, typeof(variable_data), VariableNodeDataInterface))
end

"""
    get_value(variable_data::VariableNodeDataInterface)

Get the value of the variable node data.
"""
function get_value(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_value, typeof(variable_data), VariableNodeDataInterface))
end

"""
    is_random(variable_data::VariableNodeDataInterface)

Check if the variable node data is random.
"""
function is_random(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(is_random, typeof(variable_data), VariableNodeDataInterface))
end

"""
    is_data(variable_data::VariableNodeDataInterface)

Check if the variable node data is data.
"""
function is_data(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(is_data, typeof(variable_data), VariableNodeDataInterface))
end

"""
    is_constant(variable_data::VariableNodeDataInterface)

Check if the variable node data is constant.
"""
function is_constant(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(is_constant, typeof(variable_data), VariableNodeDataInterface))
end

"""
    is_anonymous(variable_data::VariableNodeDataInterface)

Check if the variable node data is anonymous.
"""
function is_anonymous(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(is_anonymous, typeof(variable_data), VariableNodeDataInterface))
end

"""

    get_context(variable_data::VariableNodeDataInterface)

Get the context associated with the variable node data.
"""
function get_context(variable_data::VariableNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_context, typeof(variable_data), VariableNodeDataInterface))
end

"""
    hasextra(variable_data::VariableNodeDataInterface, key::Symbol)
    hasextra(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey)

Check if the variable node data has an extra property with the given key.
"""
function has_extra(variable_data::VariableNodeDataInterface, key)
    throw(GraphPPLInterfaceNotImplemented(has_extra, typeof(variable_data), VariableNodeDataInterface))
end

"""
    get_extra(variable_data::VariableNodeDataInterface)
    get_extra(variable_data::VariableNodeDataInterface, key::Symbol)
    get_extra(variable_data::VariableNodeDataInterface, key::Symbol, default)
    get_extra(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey{K,T})::T
    get_extra(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey{K,T}, default::T)::T

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value. The NodeDataExtraKey versions provide type safety at compile time.
"""
function get_extra(variable_data::VariableNodeDataInterface, args...)
    throw(GraphPPLInterfaceNotImplemented(get_extra, typeof(variable_data), VariableNodeDataInterface))
end

"""
    set_extra!(variable_data::VariableNodeDataInterface, key::Symbol, value)
    set_extra!(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey{K,T}, value::T)

Set the extra property with the given key to the given value.
The NodeDataExtraKey version provides type safety at compile time.
"""
function set_extra!(variable_data::VariableNodeDataInterface, key, value)
    throw(GraphPPLInterfaceNotImplemented(set_extra!, typeof(variable_data), VariableNodeDataInterface))
end
