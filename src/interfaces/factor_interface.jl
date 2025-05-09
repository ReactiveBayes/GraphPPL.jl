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
function fform end

"""
    getcontext(factor_data::FactorNodeDataInterface)

Get the context associated with the factor node data.
"""
function getcontext end

"""
    hasextra(factor_data::FactorNodeDataInterface, key::Symbol)
    hasextra(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey)

Check if the factor node data has an extra property with the given key.
"""
function hasextra end

"""
    getextra(factor_data::FactorNodeDataInterface, key::Symbol)
    getextra(factor_data::FactorNodeDataInterface, key::Symbol, default)
    getextra(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey{K,T})::T
    getextra(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey{K,T}, default::T)::T

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value. The NodeDataExtraKey versions provide type safety at compile time.
"""
function getextra end

"""
    setextra!(factor_data::FactorNodeDataInterface, key::Symbol, value)
    setextra!(factor_data::FactorNodeDataInterface, key::NodeDataExtraKey{K,T}, value::T)

Set the extra property with the given key to the given value.
The NodeDataExtraKey version provides type safety at compile time.
"""
function setextra! end
