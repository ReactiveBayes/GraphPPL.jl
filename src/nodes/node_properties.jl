"""
    VariableNodeProperties(name, index, kind, link, value)

Data associated with a variable node in a probabilistic graphical model.
"""
struct VariableNodeProperties
    name::Symbol
    index::Any
    kind::Symbol
    link::Any
    value::Any
end

VariableNodeProperties(; name, index, kind = VariableKindRandom, link = nothing, value = nothing) =
    VariableNodeProperties(name, index, kind, link, value)

is_factor(::VariableNodeProperties)   = false
is_variable(::VariableNodeProperties) = true

function Base.convert(::Type{VariableNodeProperties}, name::Symbol, index, options::NodeCreationOptions)
    return VariableNodeProperties(
        name = name,
        index = index,
        kind = get(options, :kind, VariableKindRandom),
        link = get(options, :link, nothing),
        value = get(options, :value, nothing)
    )
end

getname(properties::VariableNodeProperties) = properties.name
getlink(properties::VariableNodeProperties) = properties.link
index(properties::VariableNodeProperties) = properties.index
value(properties::VariableNodeProperties) = properties.value

"Defines a `random` (or `latent`) kind for a variable in a probabilistic graphical model."
const VariableKindRandom = :random
"Defines a `data` kind for a variable in a probabilistic graphical model."
const VariableKindData = :data
"Defines a `constant` kind for a variable in a probabilistic graphical model."
const VariableKindConstant = :constant
"Placeholder for a variable kind in a probabilistic graphical model."
const VariableKindUnknown = :unknown

is_kind(properties::VariableNodeProperties, kind) = properties.kind === kind
is_kind(properties::VariableNodeProperties, ::Val{kind}) where {kind} = properties.kind === kind
is_random(properties::VariableNodeProperties) = is_kind(properties, Val(VariableKindRandom))
is_data(properties::VariableNodeProperties) = is_kind(properties, Val(VariableKindData))
is_constant(properties::VariableNodeProperties) = is_kind(properties, Val(VariableKindConstant))

const VariableNameAnonymous = :anonymous_var_graphppl

is_anonymous(properties::VariableNodeProperties) = properties.name === VariableNameAnonymous

function Base.show(io::IO, properties::VariableNodeProperties)
    print(io, "name = ", properties.name, ", index = ", properties.index)
    if !isnothing(properties.link)
        print(io, ", linked to ", properties.link)
    end
end

"""
    FactorNodeProperties(fform, neighbours)

Data associated with a factor node in a probabilistic graphical model.
"""
struct FactorNodeProperties{D}
    fform::Any
    neighbors::Vector{Tuple{NodeLabel, EdgeLabel, D}}
end

FactorNodeProperties(; fform, neighbors = Tuple{NodeLabel, EdgeLabel, NodeData}[]) = FactorNodeProperties(fform, neighbors)

is_factor(::FactorNodeProperties)   = true
is_variable(::FactorNodeProperties) = false

function Base.convert(::Type{FactorNodeProperties}, fform, options::NodeCreationOptions)
    return FactorNodeProperties(fform = fform, neighbors = get(options, :neighbors, Tuple{NodeLabel, EdgeLabel, NodeData}[]))
end

getname(properties::FactorNodeProperties) = string(properties.fform)
prettyname(properties::FactorNodeProperties) = prettyname(properties.fform)
prettyname(fform::Any) = string(fform) # Can be overloaded for custom pretty names

fform(properties::FactorNodeProperties) = properties.fform
neighbors(properties::FactorNodeProperties) = properties.neighbors
addneighbor!(properties::FactorNodeProperties, variable::NodeLabel, edge::EdgeLabel, data) =
    push!(properties.neighbors, (variable, edge, data))
neighbor_data(properties::FactorNodeProperties) = Iterators.map(neighbor -> neighbor[3], neighbors(properties))

function Base.show(io::IO, properties::FactorNodeProperties)
    print(io, "fform = ", properties.fform, ", neighbors = ", properties.neighbors)
end