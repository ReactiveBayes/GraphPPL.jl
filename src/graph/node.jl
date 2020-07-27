export FactorNode

abstract type Node end

mutable struct FactorNode{F}
    fn::F
    interfaces::Vector{Symbol}
    neighbors::Vector{<:Node}
end

mutable struct Variable <: Node
    id::Symbol
    neighbors::Set{<:Node}
end

function Variable(id::Symbol)
    return Variable(id, Set{FactorNode}())
end
