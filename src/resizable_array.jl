import Base: size, setindex!, getindex, show

struct ResizableArray{T,V<:AbstractVector,N} <: AbstractArray{T,N}
    data::V
end

ResizableArray(::Type{T}) where {T} = ResizableArray{T,Vector{T},1}(T[])

function ResizableArray(::Type{T}, ::Val{N}) where {T,N}
    data = make_recursive_vector(T, Val(N))
    V = typeof(data)
    return ResizableArray{T,V,N}(data)
end

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
) where {N,V <: Vector,T}
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

function getindex(array::ResizableArray{T,V,N}, index...) where {T,V,N}
    @assert N >= length(index) "Invalid index $(index) for $(array) of shape $(size(array)))"
    return recursive_getindex(Val(length(index)), array.data, index...)
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
