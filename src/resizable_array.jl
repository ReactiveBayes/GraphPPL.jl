import Base: size, setindex!, getindex, show, vec

struct ResizableArray{T,V<:AbstractVector,N} <: AbstractArray{T,N}
    data::V
end

ResizableArray(::Type{T}) where {T} = ResizableArray{T,Vector{T},1}(T[])

function ResizableArray(::Type{T}, ::Val{N}) where {T,N}
    data = make_recursive_vector(T, Val(N))
    V = typeof(data)
    return ResizableArray{T,V,N}(data)
end

function get_recursive_depth(v::AbstractVector)
    return 1 + get_recursive_depth(first(v))
end

get_recursive_depth(any) = 0

function reltype(v::AbstractVector)
    return reltype(first(v))
end
reltype(any::T) where {T} = T

function ResizableArray(array::AbstractVector{T}) where {T}
    V = reltype(array)
    return ResizableArray{V,Vector{T},get_recursive_depth(array)}(array)
end

ResizableArray(A::AbstractArray) = ResizableArray([A[:, i] for i = 1:size(A, 2)])

function make_recursive_vector(::Type{T}, ::Val{1}) where {T}
    return T[]
end

function make_recursive_vector(::Type{T}, ::Val{N}) where {T,N}
    return fill(make_recursive_vector(T, Val(N - 1)), 0)
end

function Base.size(array::ResizableArray{T,V,N}) where {T,V,N}
    return recursive_size(Val(N), array.data)
end

function recursive_size(::Val{1}, vector::Vector{T}) where {T}
    return (length(vector),)
end

function recursive_size(::Val{N}, vector::Vector{T}) where {N,T<:Vector}
    l = length(vector)
    sz = map((v) -> recursive_size(Val(N - 1), v), vector)
    msz = reduce((a, b) -> max.(a, b), sz; init = ntuple(_ -> 0, N - 1))
    return (l, msz...)
end

function setindex!(array::ResizableArray{T,V,N}, value, index...) where {T,V,N}
    @assert N === length(index) "Invalid index $(index) for $(array)"
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

function recursive_setindex!(
    ::Val{N},
    array::Vector{V},
    value::T,
    findex,
    index...,
) where {N,V<:Vector,T}
    if findex > length(array)
        oldlength = length(array)
        resize!(array, findex)
        for i = (oldlength+1):findex
            array[i] = make_recursive_vector(T, Val(N - 1))
        end
    end
    recursive_setindex!(Val(N - 1), array[findex], value, index...)
    return nothing
end

function getindex(array::ResizableArray{T,V,N}, index::Vararg{Int}) where {T,V,N}
    @assert N >= length(index) "Invalid index $(index) for $(array) of shape $(size(array)))"
    return recursive_getindex(Val(length(index)), array.data, index...)
end

function getindex(array::ResizableArray{T,V,N}, index::Vararg{CartesianIndex}) where {T,V,N}
    return getindex(array, first(index).I...)
end

function recursive_getindex(::Val{1}, array::Vector, index)
    return array[index]
end

function recursive_getindex(::Val{N}, array::Vector{V}, findex, index...) where {N,V}
    return recursive_getindex(Val(N - 1), array[findex], index...)
end

function Base.show(io::IO, array::ResizableArray{T,V,N}) where {T,V,N}
    print(io, "ResizableArray{$T,$N}(")
    show(io, array.data)
    print(io, ")")
end

function vec(array::ResizableArray{T,V,N}) where {T,V,N}
    result = T[]
    for index in Tuple.(CartesianIndices(size(array)))
        if isassigned(array, index...)
            push!(result, array[index...])
        end
    end
    return result
end

Base.iterate(array::ResizableArray{T,V,N}, state = 1) where {T,V,N} =
    iterate(array.data, state)

function Base.first(array::ResizableArray{T,V,N}) where {T,V,N}
    for index in Tuple.(CartesianIndices(size(array)))
        if isassigned(array, index...)
            return array[index...]
        end
    end
end
