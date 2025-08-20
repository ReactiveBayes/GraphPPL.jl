"""
    VarDict

A recursive dictionary structure that contains all variables in a probabilistic graphical model.
Iterates over all variables in the model and their children in a linear fashion, but preserves the recursive nature of the actual model.
"""
struct VarDict{T}
    variables::UnorderedDictionary{Symbol, T}
    children::UnorderedDictionary{FactorID, VarDict}
end

function VarDict(context::Context)
    dictvariables = merge(individual_variables(context), vector_variables(context), tensor_variables(context))
    dictchildren = convert(UnorderedDictionary{FactorID, VarDict}, map(child -> VarDict(child), children(context)))
    return VarDict(dictvariables, dictchildren)
end

variables(vardict::VarDict) = vardict.variables
children(vardict::VarDict) = vardict.children

haskey(vardict::VarDict, key::Symbol) = haskey(vardict.variables, key)
haskey(vardict::VarDict, key::Tuple{T, Int} where {T}) = haskey(vardict.children, FactorID(first(key), last(key)))
haskey(vardict::VarDict, key::FactorID) = haskey(vardict.children, key)

Base.getindex(vardict::VarDict, key::Symbol) = vardict.variables[key]
Base.getindex(vardict::VarDict, f, index::Int) = vardict.children[FactorID(f, index)]
Base.getindex(vardict::VarDict, key::Tuple{T, Int} where {T}) = vardict.children[FactorID(first(key), last(key))]
Base.getindex(vardict::VarDict, key::FactorID) = vardict.children[key]

function Base.map(f, vardict::VarDict)
    mapped_variables = map(f, variables(vardict))
    mapped_children = convert(UnorderedDictionary{FactorID, VarDict}, map(child -> map(f, child), children(vardict)))
    return VarDict(mapped_variables, mapped_children)
end

function Base.filter(f, vardict::VarDict)
    filtered_variables = filter(f, variables(vardict))
    filtered_children = convert(UnorderedDictionary{FactorID, VarDict}, map(child -> filter(f, child), children(vardict)))
    return VarDict(filtered_variables, filtered_children)
end

Base.:(==)(left::VarDict, right::VarDict) = left.variables == right.variables && left.children == right.children