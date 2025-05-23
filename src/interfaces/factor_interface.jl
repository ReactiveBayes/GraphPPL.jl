"""
    FactorNodeDataInterface

Abstract interface for factor node data in a factor graph. Contains the actual data stored
for a factor node in the model. Models can implement specific types that extend this interface.
"""
abstract type FactorNodeDataInterface end

"""
    get_functional_form(factor_data::F) where {F<:FactorNodeDataInterface}

Get the functional form of the factor node data.

# Returns
The functional form associated with this factor node.
"""
function get_functional_form(::F) where {F <: FactorNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_functional_form, F, FactorNodeDataInterface))
end

"""
    has_extra(factor_data::F, key) where {F<:FactorNodeDataInterface}

Check if the factor node data has an extra property with the given key.

# Arguments
- `factor_data`: The factor node data to check
- `key`: The key to look up in the extra properties

# Returns
`true` if the extra property exists, `false` otherwise
"""
function has_extra(::F, key) where {F <: FactorNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(has_extra, F, FactorNodeDataInterface))
end

"""
    get_extra(factor_data::F, key) where {F<:FactorNodeDataInterface}
    get_extra(factor_data::F, key, default) where {F<:FactorNodeDataInterface}

Get the extra property with the given key. If a form with a default value is used and the property
does not exist, returns the default value.

# Arguments
- `factor_data`: The factor node data to query
- `key`: The key to look up in the extra properties
- `default`: Optional default value to return if the key doesn't exist

# Returns
The value associated with the key, or the default value if provided and the key doesn't exist
"""
function get_extra(::F, args...) where {F <: FactorNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(get_extra, F, FactorNodeDataInterface))
end

"""
    set_extra!(factor_data::F, key, value) where {F<:FactorNodeDataInterface}

Set the extra property with the given key to the given value.

# Arguments
- `factor_data`: The factor node data to modify
- `key`: The key to set in the extra properties
- `value`: The value to associate with the key
"""
function set_extra!(::F, key, value) where {F <: FactorNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(set_extra!, F, FactorNodeDataInterface))
end

"""
    create_factor_data(::Type{T}; functional_form) where {T<:FactorNodeDataInterface}

Create factor node data for the given functional form.

# Arguments
- `::Type{T}`: The concrete type of factor node data to create
- `functional_form`: The functional form for the factor node

# Returns
An instance of type T containing the factor node data
"""
function create_factor_data(::Type{T}; functional_form) where {T <: FactorNodeDataInterface}
    throw(GraphPPLInterfaceNotImplemented(create_factor_data, T, FactorNodeDataInterface))
end
