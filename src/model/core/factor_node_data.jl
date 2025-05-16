"""
    FactorNodeData <: FactorNodeDataInterface

Concrete implementation of `FactorNodeDataInterface` that stores data for a factor node in a factor graph.
"""
struct FactorNodeData <: FactorNodeDataInterface
    """Functional form of the factor node."""
    form::Any

    """Context associated with the factor node."""
    context::Any

    """Dictionary of extra properties associated with the factor node."""
    extras::Dict{Symbol, Any}

    """
        FactorNodeData(form, context = nothing)

    Create a new factor node data with the given functional form and optional context.
    """
    function FactorNodeData(form, context = nothing)
        new(form, context, Dict{Symbol, Any}())
    end
end

"""
    get_functional_form(factor_data::FactorNodeData)

Get the functional form of the factor node data.
"""
function get_functional_form(factor_data::FactorNodeData)
    return factor_data.form
end

"""
    get_context(factor_data::FactorNodeData)

Get the context associated with the factor node data.
"""
function get_context(factor_data::FactorNodeData)
    return factor_data.context
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
    return factor_data.extras[get_key(key)]::T
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
    return get(factor_data.extras, get_key(key), default)::T
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
    Base.show(io::IO, data::FactorNodeData)

Custom display method for FactorNodeData.
"""
function Base.show(io::IO, data::FactorNodeData)
    print(io, "FactorNodeData(form=$(data.form), context=$(data.context), extras=$(data.extras))")
end

function create_factor_data(::Type{FactorNodeData}, context::Any, fform::Any; kwargs...)
    return FactorNodeData(fform, context)
end
