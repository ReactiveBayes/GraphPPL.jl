mutable struct FactorGraph
    nodes::Set{Node}
    variables::Set{Variable}
    edges::Set{Edge}

    # Any relevant metadata
    meta::Dict{Symbol, Any}
end
