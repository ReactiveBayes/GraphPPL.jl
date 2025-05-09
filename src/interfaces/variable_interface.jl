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
function get_name end

"""
    get_link(variable_data::VariableNodeDataInterface)

Get the link of the variable node data.
"""
function get_link end

"""
    get_kind(variable_data::VariableNodeDataInterface)

Get the kind of the variable node data.
"""
function get_kind end

"""
    get_value(variable_data::VariableNodeDataInterface)

Get the value of the variable node data.
"""
function get_value end

"""
    is_constant(variable_data::VariableNodeDataInterface)

Check if the variable node data is constant.
"""
function is_constant end

"""
    getcontext(variable_data::VariableNodeDataInterface)

Get the context associated with the variable node data.
"""
function getcontext end

"""
    hasextra(variable_data::VariableNodeDataInterface, key::Symbol)
    hasextra(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey)

Check if the variable node data has an extra property with the given key.
"""
function hasextra end

"""
    getextra(variable_data::VariableNodeDataInterface, key::Symbol)
    getextra(variable_data::VariableNodeDataInterface, key::Symbol, default)
    getextra(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey{K,T})::T
    getextra(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey{K,T}, default::T)::T

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value. The NodeDataExtraKey versions provide type safety at compile time.
"""
function getextra end

"""
    setextra!(variable_data::VariableNodeDataInterface, key::Symbol, value)
    setextra!(variable_data::VariableNodeDataInterface, key::NodeDataExtraKey{K,T}, value::T)

Set the extra property with the given key to the given value.
The NodeDataExtraKey version provides type safety at compile time.
"""
function setextra! end
