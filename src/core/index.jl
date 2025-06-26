"""
    Index{D}

A parametric struct representing a multi-dimensional index.

The `Index` type stores a tuple of integers representing indices in different dimensions.
Used primarily for dispatching on the dimensionality of the index 
within [`GraphPPL.get_variable`](@ref) and [`GraphPPL.set_variable!`](@ref) functions.
"""
struct Index{D}
    indices::NTuple{D, Int}
end

function Index(indices::Vararg{Int, D}) where {D}
    Index{D}(indices)
end

"""
    get_index_dimensionality(index::Index{D}) where {D}

Get the dimensionality of an `Index` as a compile-time constant.

# Arguments
- `index::Index{D}`: The index to query

# Returns
- `StaticInt(D)`: The dimensionality as a static integer
"""
function get_index_dimensionality(::Index{D}) where {D}
    return StaticInt(D)
end