"""
    IndexedVariable(name, index)

`IndexedVariable` represents a reference to a variable named `name` with index `index`. 
"""
struct IndexedVariable{T}
    name::Symbol
    index::T
end

getname(index::IndexedVariable) = index.name
index(index::IndexedVariable) = index.index

Base.length(index::IndexedVariable{T} where {T}) = 1
Base.iterate(index::IndexedVariable{T} where {T}) = (index, nothing)
Base.iterate(index::IndexedVariable{T} where {T}, any) = nothing
Base.:(==)(left::IndexedVariable, right::IndexedVariable) = (left.name == right.name && left.index == right.index)
Base.show(io::IO, variable::IndexedVariable{Nothing}) = print(io, variable.name)
Base.show(io::IO, variable::IndexedVariable) = print(io, variable.name, "[", variable.index, "]")

Base.getindex(context::T, ivar::IndexedVariable{Nothing}) where {T} = Base.getindex(context, getname(ivar))
Base.getindex(context::T, ivar::IndexedVariable) where {T} = Base.getindex(context, getname(ivar))[index(ivar)]