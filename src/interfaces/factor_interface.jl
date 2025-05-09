"""
    FactorNodeDataInterface

Abstract interface for factor node data in a factor graph. Contains the actual data stored
for a factor node in the model. Models can implement specific types that extend this interface.
"""
abstract type FactorNodeDataInterface end

"""
    fform(factor_data::FactorNodeDataInterface)

Get the functional form of the factor node data.
"""
function fform(factor_data::FactorNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(fform, typeof(factor_data), FactorNodeDataInterface))
end

"""
    get_context(factor_data::FactorNodeDataInterface)

Get the context associated with the factor node data.
"""
function get_context(factor_data::FactorNodeDataInterface)
    throw(GraphPPLInterfaceNotImplemented(get_context, typeof(factor_data), FactorNodeDataInterface))
end

"""
    has_extra(factor_data::FactorNodeDataInterface, key::Symbol)
    has_extra(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey)

Check if the factor node data has an extra property with the given key.
"""
function has_extra(factor_data::FactorNodeDataInterface, key)
    throw(GraphPPLInterfaceNotImplemented(has_extra, typeof(factor_data), FactorNodeDataInterface))
end

"""
    get_extra(factor_data::FactorNodeDataInterface, key::Symbol)
    get_extra(factor_data::FactorNodeDataInterface, key::Symbol)
    get_extra(factor_data::FactorNodeDataInterface, key::Symbol, default)
    get_extra(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey{K,T})::T
    get_extra(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey{K,T}, default::T)::T

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value. The NodeDataExtraKey versions provide type safety at compile time.
"""
function get_extra(factor_data::FactorNodeDataInterface, args...)
    throw(GraphPPLInterfaceNotImplemented(get_extra, typeof(factor_data), FactorNodeDataInterface))
end

"""
    set_extra!(factor_data::FactorNodeDataInterface, key::Symbol, value)
    set_extra!(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey{K,T}, value::T)

Set the extra property with the given key to the given value.
The NodeDataExtraKey version provides type safety at compile time.
"""
function set_extra!(factor_data::FactorNodeDataInterface, key, value)
    throw(GraphPPLInterfaceNotImplemented(set_extra!, typeof(factor_data), FactorNodeDataInterface))
end
