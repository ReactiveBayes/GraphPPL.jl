"""
    FunctionalIndex

A special type of an index that represents a function that can be used only in pair with a collection. 
An example of a `FunctionalIndex` can be `firstindex` or `lastindex`, but more complex use cases are possible too, 
e.g. `firstindex + 1`. Important part of the implementation is that the resulting structure is `isbitstype(...) = true`, 
that allows to store it in parametric type as valtype. One use case for this structure is to dispatch on and to replace `begin` or `end` 
(or more complex use cases, e.g. `begin + 1`).
"""
struct FunctionalIndex{R, F}
    f::F
    FunctionalIndex{R}(f::F) where {R, F} = new{R, F}(f)
end

"""
    (index::FunctionalIndex)(collection)

Returns the result of applying the function `f` to the collection.

```jldoctest
julia> index = GraphPPL.FunctionalIndex{:begin}(firstindex)
(begin)

julia> index([ 2.0, 3.0 ])
1

julia> (index + 1)([ 2.0, 3.0 ])
2

julia> index = GraphPPL.FunctionalIndex{:end}(lastindex)
(end)

julia> index([ 2.0, 3.0 ])
2
```
"""
(index::FunctionalIndex{R, F})(collection) where {R, F} = __functional_index_apply(R, index.f, collection)::Integer

Base.getindex(x::AbstractArray, fi::FunctionalIndex) = x[fi(x)]
# Base.getindex(x::NodeLabel, index::FunctionalIndex) = index(x)

__functional_index_apply(::Symbol, f, collection) = f(collection)
__functional_index_apply(subindex::FunctionalIndex, f::Tuple{typeof(+), <:Integer}, collection) = subindex(collection) .+ f[2]
__functional_index_apply(subindex::FunctionalIndex, f::Tuple{typeof(-), <:Integer}, collection) = subindex(collection) .- f[2]

Base.:(+)(left::FunctionalIndex, index::Integer) = FunctionalIndex{left}((+, index))
Base.:(-)(left::FunctionalIndex, index::Integer) = FunctionalIndex{left}((-, index))

__functional_index_print(io::IO, f::typeof(firstindex)) = nothing
__functional_index_print(io::IO, f::typeof(lastindex)) = nothing
__functional_index_print(io::IO, f::Tuple{typeof(+), <:Integer}) = print(io, " + ", f[2])
__functional_index_print(io::IO, f::Tuple{typeof(-), <:Integer}) = print(io, " - ", f[2])

function Base.show(io::IO, index::FunctionalIndex{R, F}) where {R, F}
    print(io, "(")
    print(io, R)
    __functional_index_print(io, index.f)
    print(io, ")")
end

"""
    FunctionalRange(left, range)

A range can handle `FunctionalIndex` as one of (or both) the bounds.

```jldoctest
julia> first = GraphPPL.FunctionalIndex{:begin}(firstindex)
(begin)

julia> last = GraphPPL.FunctionalIndex{:end}(lastindex)
(end)

julia> range = GraphPPL.FunctionalRange(first + 1, last - 1)
((begin) + 1):((end) - 1)

julia> [ 1.0, 2.0, 3.0, 4.0 ][range]
2-element Vector{Float64}:
 2.0
 3.0
```
"""
struct FunctionalRange{L, R}
    left::L
    right::R
end

(::Colon)(left, right::FunctionalIndex) = FunctionalRange(left, right)
(::Colon)(left::FunctionalIndex, right) = FunctionalRange(left, right)
(::Colon)(left::FunctionalIndex, right::FunctionalIndex) = FunctionalRange(left, right)

Base.getindex(collection::AbstractArray, range::FunctionalRange{L, R}) where {L, R <: FunctionalIndex} =
    collection[(range.left):range.right(collection)]
Base.getindex(collection::AbstractArray, range::FunctionalRange{L, R}) where {L <: FunctionalIndex, R} =
    collection[range.left(collection):(range.right)]
Base.getindex(collection::AbstractArray, range::FunctionalRange{L, R}) where {L <: FunctionalIndex, R <: FunctionalIndex} =
    collection[range.left(collection):range.right(collection)]

function Base.show(io::IO, range::FunctionalRange)
    print(io, range.left, ":", range.right)
end