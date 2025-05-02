import Base: size, setindex!, getindex, show, vec

"""
    ResizableArray{T, V, N} <: AbstractArray{T, N}

A ResizableArray is an array that can grow in any dimension. It handles like a regular AbstractArray when calling `getindex`, but for `setindex!` 
it will automatically resize the array if the index is out of bounds. It is also possible to iterate over the array in the same way as for a regular array.
The data is stored internally as a recursive vector. The depth of the recursion is fixed at construction time and cannot be changed. 

# Constructor
- `ResizableArray(::Type{T})`: Create an empty resizable array of type `T` with depth 1, similar to a vector.
- `ResizableArray(::Type{T}, ::Val{N})`: Create an empty resizable array of type `T` with depth `N`, similar to AbstractArray{T, N}.
"""
struct ResizableArray{T, V <: AbstractVector, N} <: AbstractArray{T, N}
    data::V
end

ResizableArray(::Type{T}) where {T} = ResizableArray{T, Vector{T}, 1}(T[])

similar(::ResizableArray{T, V, N}) where {T, V, N} = ResizableArray(T, Val(N))

function ResizableArray(::Type{T}, ::Val{N}) where {T, N}
    data = make_recursive_vector(T, Val(N))
    V = typeof(data)
    return ResizableArray{T, V, N}(data)
end

function get_recursive_depth(v::AbstractVector)
    return 1 + get_recursive_depth(first(v))
end

get_recursive_depth(any) = 0

function reltype(::Type{<:AbstractVector{<:T}}) where {T <: AbstractArray}
    return reltype(T)
end

function reltype(::Type{<:AbstractVector{T}}) where {T}
    return T
end

function ResizableArray(array::AbstractVector{T}) where {T}
    V = reltype(typeof(array))
    return ResizableArray{V, Vector{T}, get_recursive_depth(array)}(array)
end

function make_recursive_vector(::Type{T}, ::Val{1}) where {T}
    return T[]
end

function make_recursive_vector(::Type{T}, ::Val{N}) where {T, N}
    return fill(make_recursive_vector(T, Val(N - 1)), 0)
end

function Base.size(array::ResizableArray{T, V, N}) where {T, V, N}
    return recursive_size(Val(N), array.data)
end

function recursive_size(::Val{1}, vector::Vector{T}) where {T}
    return (length(vector),)
end

function recursive_size(::Val{N}, vector::Vector{T}) where {N, T <: Vector}
    l = length(vector)
    sz = map((v) -> recursive_size(Val(N - 1), v), vector)
    msz = reduce((a, b) -> max.(a, b), sz; init = ntuple(_ -> 0, N - 1))
    return (l, msz...)
end

function setindex!(array::ResizableArray{T, V, N}, value, index...) where {T, V, N}
    if !(N === length(index))
        error(lazy"Invalid index $(index) for $(array)")
    end
    recursive_setindex!(Val(N), array.data, value, index...)
    return array
end

function recursive_setindex!(::Val{1}, array::Vector{T}, value::T, index) where {T}
    if index == length(array) + 1
        push!(array, value)
    elseif index > length(array) + 1
        resize!(array, index)
        array[index] = value
    else
        array[index] = value
    end
    return nothing
end

function recursive_setindex!(::Val{N}, array::Vector{V}, value::T, findex, index...) where {N, V <: Vector, T}
    if findex > length(array)
        oldlength = length(array)
        resize!(array, findex)
        for i in (oldlength + 1):findex
            array[i] = make_recursive_vector(T, Val(N - 1))
        end
    end
    recursive_setindex!(Val(N - 1), array[findex], value, index...)
    return nothing
end

function Base.isassigned(array::ResizableArray{T, V, N}, index::Integer...)::Bool where {T, V, N}
    if length(index) !== N
        return false
    else
        return recursive_isassigned(Val(N), array.data, index)::Bool
    end
end

function recursive_isassigned(::Val{N}, array, indices)::Bool where {N}
    findex = first(indices)
    tindices = Base.tail(indices)
    if isassigned(array, findex)::Bool
        return recursive_isassigned(Val(N - 1), @inbounds(array[findex]), tindices)::Bool
    else
        return false
    end
end

function recursive_isassigned(::Val{1}, array, index::Tuple{Integer})::Bool
    return isassigned(array, first(index))::Bool
end

function getindex(array::ResizableArray{T, V, N}, index::UnitRange) where {T, V, N}
    return ResizableArray(array.data[index])
end

function getindex(array::ResizableArray{T, V, N}, index::Vararg{UnitRange}) where {T, V, N}
    return ResizableArray(recursive_getindex(Val(length(index)), array.data, index...))
end

function getindex(array::ResizableArray{T, V, N}, index::Vararg{Int}) where {T, V, N}
    if !(N >= length(index))
        error(lazy"Invalid index $(index) for $(array) of shape $(size(array)))")
    end
    return recursive_getindex(Val(length(index)), array.data, index...)
end

function getindex(array::ResizableArray{T, V, N}, index::Vararg{CartesianIndex}) where {T, V, N}
    return getindex(array, first(index).I...)
end

function recursive_getindex(::Val{1}, array::Vector, index)
    return array[index]
end

function recursive_getindex(::Val{1}, array::Vector, index::UnitRange)
    return array[index]
end

function recursive_getindex(::Val{N}, array::Vector{V}, findex, index...) where {N, V}
    return recursive_getindex(Val(N - 1), array[findex], index...)
end

function recursive_getindex(::Val{N}, array::Vector{V}, findex::UnitRange, index...) where {N, V}
    return [recursive_getindex(Val(N - 1), array[i], index...) for i in findex]
end

function Base.show(io::IO, array::ResizableArray{T, V, N}) where {T, V, N}
    print(io, "ResizableArray{$T,$N}(")
    show(io, array.data)
    print(io, ")")
end

function vec(array::ResizableArray{T, V, N}) where {T, V, N}
    result = T[]
    for index in CartesianIndices(size(array))
        if isassigned(array, index.I...)::Bool
            push!(result, array[index.I...])
        end
    end
    return result
end

function Base.iterate(array::ResizableArray)
    # We want to emulate the same iteration protocol as for the `Array` structure 
    # which iterates over the last dimension first
    indx = CartesianIndices(size(array))
    pindex, pstate = iterate(indx)
    return (array[pindex.I...], isnothing(pstate) ? nothing : (indx, pstate))
end

function Base.iterate(array::ResizableArray, state)
    if isnothing(state)
        return nothing
    end
    indx, pstate = state
    niterate = iterate(indx, pstate)
    if isnothing(niterate)
        return nothing
    end
    nindex, nstate = niterate
    return (array[nindex.I...], isnothing(nstate) ? nothing : (indx, nstate))
end

__length(array::ResizableArray{T, V, N}) where {T, V, N} = __recursive_length(Val(N), array.data)

function __recursive_length(::Val{N}, array) where {N}
    if length(array) == 0
        return 0
    end
    return sum((arr) -> __recursive_length(Val(N - 1), arr), array)
end

__recursive_length(::Val{1}, array) = length(array) == 0 ? 0 : sum((x) -> isassigned(array, x), 1:length(array))

function flattened_index(array::ResizableArray{T, V, N}, index::NTuple{N, Int}) where {T, V, N}
    return __flattened_index(Val(N), array.data, index...)
end

flattened_index(array::ResizableArray{T, V, 1}, index::Int) where {T, V} = __flattened_index(Val(1), array.data, index)

function __flattened_index(::Val{1}, array::Vector{T}, index) where {T}
    if isassigned(array, index)
        return index
    else
        return sum((x) -> isassigned(array, x), 1:index)
    end
end

function __flattened_index(::Val{N}, array::Vector{V}, findex, index...) where {N, V}
    if findex == 1
        return __flattened_index(Val(N - 1), array[findex], index...)
    else
        return sum(i -> __recursive_length(Val(N - 1), array[i]), 1:(findex - 1)) + __flattened_index(Val(N - 1), array[findex], index...)
    end
end

function Base.first(array::ResizableArray{T, V, N}) where {T, V, N}
    for index in CartesianIndices(size(array)) #TODO improve performance of this function since it uses splatting
        if isassigned(array, index.I...)::Bool
            return array[index.I...]
        end
    end
end

function firstwithindex(array::ResizableArray{T, V, N}) where {T, V, N}
    for index in CartesianIndices(size(array)) #TODO improve performance of this function since it uses splatting
        if isassigned(array, index.I...)::Bool
            return (index, array[index.I...])
        end
    end
end

function lastwithindex(array::ResizableArray{T, V, N}) where {T, V, N}
    for index in reverse(CartesianIndices(reverse(size(array)))) #TODO improve performance of this function since it uses splatting
        if isassigned(array, reverse(index.I)...)::Bool
            return (CartesianIndex(reverse(index.I)), array[reverse(index.I)...])
        end
    end
end
