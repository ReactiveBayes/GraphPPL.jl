"""
    FactorNodeData <: FactorNodeDataInterface

Concrete implementation of `FactorNodeDataInterface` that stores data for a factor node in a factor graph.

# Fields
- `functional_form::Any`: The functional form of the factor node
- `extras::Dict{Symbol, Any}`: Dictionary for storing additional properties
"""
Base.@kwdef struct FactorNodeData <: FactorNodeDataInterface
    functional_form::Any
    extras::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

"""
    get_functional_form(factor_data::FactorNodeData)

Get the functional form of the factor node data.
"""
function get_functional_form(factor_data::FactorNodeData)
    return factor_data.functional_form
end

"""
    has_extra(factor_data::FactorNodeData, key::Symbol)

Check if the factor node data has an extra property with the given key.
"""
function has_extra(factor_data::FactorNodeData, key::Symbol)
    return haskey(factor_data.extras, key)
end

"""
    has_extra(factor_data::FactorNodeData, key::CompileTimeDictionaryKey)

Check if the factor node data has an extra property with the given key.
"""
function has_extra(factor_data::FactorNodeData, key::CompileTimeDictionaryKey{K, T}) where {K, T}
    return haskey(factor_data.extras, get_key(key))
end

"""
    get_extra(factor_data::FactorNodeData, key::Symbol)

Get the extra property with the given key.
"""
function get_extra(factor_data::FactorNodeData, key::Symbol)
    return factor_data.extras[key]
end

"""
    get_extra(factor_data::FactorNodeData, key::CompileTimeDictionaryKey)

Get the extra property with the given key.
"""
function get_extra(factor_data::FactorNodeData, key::CompileTimeDictionaryKey{K, T}) where {K, T}
    return convert(T, factor_data.extras[get_key(key)])::T
end

"""
    get_extra(factor_data::FactorNodeData, key::Symbol, default)

Get the extra property with the given key. If the property does not exist, returns the default value.
"""
function get_extra(factor_data::FactorNodeData, key::Symbol, default)
    return get(factor_data.extras, key, default)
end

"""
    get_extra(factor_data::FactorNodeData, key::CompileTimeDictionaryKey, default)

Get the extra property with the given key. If the property does not exist, returns the default value.
"""
function get_extra(factor_data::FactorNodeData, key::CompileTimeDictionaryKey{K, T}, default) where {K, T}
    return convert(T, get(factor_data.extras, get_key(key), default))::T
end

"""
    set_extra!(factor_data::FactorNodeData, key::Symbol, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(factor_data::FactorNodeData, key::Symbol, value)
    factor_data.extras[key] = value
    return value
end

"""
    set_extra!(factor_data::FactorNodeData, key::Symbol, value)

Set the extra property with the given key to the given value.
"""
function set_extra!(factor_data::FactorNodeData, key::CompileTimeDictionaryKey{K, T}, value::T) where {K, T}
    factor_data.extras[get_key(key)] = value
    return value
end

"""
    create_factor_data(::Type{FactorNodeData}; functional_form)

Create a new factor node data of type `FactorNodeData` with the given functional form.
"""
function create_factor_data(::Type{FactorNodeData}; functional_form)
    return FactorNodeData(functional_form = functional_form)
end
