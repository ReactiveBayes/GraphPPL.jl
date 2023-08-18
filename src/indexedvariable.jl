
"""
    FunctionalIndex

A special type of an index that represents a function that can be used only in pair with a collection. 
An example of a `FunctionalIndex` can be `firstindex` or `lastindex`, but more complex use cases are possible too, 
e.g. `firstindex + 1`. Important part of the implementation is that the resulting structure is `isbitstype(...) = true`, that allows to store it in parametric type as valtype.

One use case for this structure is to dispatch on and to replace `begin` or `end` (or more complex use cases, e.g. `begin + 1`) markers in constraints specification language.
"""
struct FunctionalIndex{R,F}
    f::F
    FunctionalIndex{R}(f::F) where {R,F} = new{R,F}(f)
end

"""
    FunctionalIndex(collection)

Returns the result of applying the function `f` to the collection.
"""
(index::FunctionalIndex{R,F})(collection) where {R,F} =
    __functional_index_apply(R, index.f, collection)::Integer

Base.getindex(x::AbstractArray, index::FunctionalIndex) = x[index(x)]
# Base.getindex(x::NodeLabel, index::FunctionalIndex) = index(x)


__functional_index_apply(::Symbol, f, collection) = f(collection)
__functional_index_apply(
    subindex::FunctionalIndex,
    f::Tuple{typeof(+),<:Integer},
    collection,
) = subindex(collection) .+ f[2]
__functional_index_apply(
    subindex::FunctionalIndex,
    f::Tuple{typeof(-),<:Integer},
    collection,
) = subindex(collection) .- f[2]

Base.:(+)(left::FunctionalIndex, index::Integer) = FunctionalIndex{left}((+, index))
Base.:(-)(left::FunctionalIndex, index::Integer) = FunctionalIndex{left}((-, index))

__functional_index_print(io::IO, f::typeof(firstindex)) = nothing
__functional_index_print(io::IO, f::typeof(lastindex)) = nothing
__functional_index_print(io::IO, f::Tuple{typeof(+),<:Integer}) = print(io, " + ", f[2])
__functional_index_print(io::IO, f::Tuple{typeof(-),<:Integer}) = print(io, " - ", f[2])

function Base.show(io::IO, index::FunctionalIndex{R,F}) where {R,F}
    print(io, "(")
    print(io, R)
    __functional_index_print(io, index.f)
    print(io, ")")
end


"""
    IndexedVariable

`IndexedVariable` represents a variable with index in factorization specification language. An IndexedVariable is generally part of a vector or tensor of random variables.
"""
struct IndexedVariable{T}
    variable::Symbol
    index::T
end
getvariable(index::IndexedVariable) = index.variable
getindex(index::IndexedVariable) = index.index

Base.length(index::IndexedVariable{T} where {T}) = 1
Base.iterate(index::IndexedVariable{T} where {T}) = (index, nothing)
Base.iterate(index::IndexedVariable{T} where {T}, any) = nothing
Base.:(==)(left::IndexedVariable, right::IndexedVariable) =
    (left.variable == right.variable && left.index == right.index)
Base.show(io::IO, variable::IndexedVariable{Nothing}) = print(io, variable.variable)
Base.show(io::IO, variable::IndexedVariable) =
    print(io, variable.variable, "[", variable.index, "]")
