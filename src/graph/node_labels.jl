"""
    NodeLabel(name, global_counter::Int64)

Unique identifier for a node (factor or variable) in a probabilistic graphical model.
"""
mutable struct NodeLabel
    const name::Any
    const global_counter::Int64
end

Base.length(label::NodeLabel) = 1
Base.size(label::NodeLabel) = ()
Base.getindex(label::NodeLabel, any) = label
Base.:(<)(left::NodeLabel, right::NodeLabel) = left.global_counter < right.global_counter
Base.broadcastable(label::NodeLabel) = Ref(label)

getname(label::NodeLabel) = label.name
getname(labels::ResizableArray{T, V, N} where {T <: NodeLabel, V, N}) = getname(first(labels))
iterate(label::NodeLabel) = (label, nothing)
iterate(label::NodeLabel, any) = nothing

to_symbol(label::NodeLabel) = to_symbol(label.name, label.global_counter)
to_symbol(name::Any, index::Int) = Symbol(string(name, "_", index))

Base.show(io::IO, label::NodeLabel) = print(io, label.name, "_", label.global_counter)
Base.:(==)(label1::NodeLabel, label2::NodeLabel) = label1.name == label2.name && label1.global_counter == label2.global_counter
Base.hash(label::NodeLabel, h::UInt) = hash(label.global_counter, h)

"""
    EdgeLabel(symbol, index)

A unique identifier for an edge in a probabilistic graphical model.
"""
mutable struct EdgeLabel
    const name::Symbol
    const index::Union{Int, Nothing}
end

getname(label::EdgeLabel) = label.name
getname(labels::Tuple) = map(group -> getname(group), labels)

to_symbol(label::EdgeLabel) = to_symbol(label, label.index)
to_symbol(label::EdgeLabel, ::Nothing) = label.name
to_symbol(label::EdgeLabel, ::Int64) = Symbol(string(label.name) * "[" * string(label.index) * "]")

Base.show(io::IO, label::EdgeLabel) = print(io, to_symbol(label))
Base.:(==)(label1::EdgeLabel, label2::EdgeLabel) = label1.name == label2.name && label1.index == label2.index
Base.hash(label::EdgeLabel, h::UInt) = hash(label.name, hash(label.index, h))

"""
    FactorID(fform, index)

A unique identifier for a factor node in a probabilistic graphical model.
"""
mutable struct FactorID{F}
    const fform::F
    const index::Int64
end

fform(id::FactorID) = id.fform
index(id::FactorID) = id.index

Base.show(io::IO, id::FactorID) = print(io, "(", fform(id), ", ", index(id), ")")
Base.:(==)(id1::FactorID{F}, id2::FactorID{T}) where {F, T} = id1.fform == id2.fform && id1.index == id2.index
Base.hash(id::FactorID, h::UInt) = hash(id.fform, hash(id.index, h))