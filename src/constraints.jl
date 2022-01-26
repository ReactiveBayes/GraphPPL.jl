export @constraints

struct FactorisationSpecExact end
struct FactorisationSpecIndexed end
struct FactorisationSpecRanged end
struct FactorisationSpecSplitRanged end

struct FactorisationSpec 
    symbol :: Symbol
    index
end

# `Node` here refers to a node in a tree, it has nothing to do with factor nodes
struct FactorisationSpecNode 
    symbols  :: Union{Nothing, Tuple}
    children :: Vector{Union{FactorisationSpec, FactorisationSpecNode}}
end

macro constraints(constraints_spec)
    if isblock(constraints_spec)
        return :(GraphPPL.@constraints () = $(constraints_spec))
    end

    if !@capture(constraints_spec, (args__) = begin body_ end)
        error("Invalid constraints specification. Constraints must have the following form:\n\n\t@constraints (args...) = begin\n\t\tbody...\n\tend\n")
    end

    

end