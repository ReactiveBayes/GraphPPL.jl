export FactorGraph

mutable struct FactorGraph
    nodes::Set{Node}
    variables::Set{Variable}
    
    # Any relevant metadata
    meta::Dict{Symbol, Any}
end

function FactorGraph()
    return FactorGraph(Set{Node}(), Set{Variable}(), Dict{Symbol, Any}())
end