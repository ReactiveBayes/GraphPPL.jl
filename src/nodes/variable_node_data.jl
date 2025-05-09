"""
    VariableNodeData

A concrete implementation of `VariableNodeDataInterface` that stores data for a variable node.

# Fields
- `name::Symbol`: The name of the variable
- `index::Any`: The index of the variable
- `link::Any`: The link to other nodes or components
- `kind::Symbol`: The kind/type of variable
- `value::Any`: The value of the variable
- `context::Any`: Context data associated with the variable
- `extras::Dict{Symbol, Any}`: Dictionary for storing additional properties
"""
@kwdef struct VariableNodeData <: VariableNodeDataInterface
    name::Symbol
    index::Any = nothing
    link::Any = nothing
    kind::Symbol = :default
    value::Any = nothing
    context::Any = nothing
    extras::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

# Interface implementation
get_name(vnd::VariableNodeData) = vnd.name
get_index(vnd::VariableNodeData) = vnd.index
get_link(vnd::VariableNodeData) = vnd.link
get_kind(vnd::VariableNodeData) = vnd.kind
get_value(vnd::VariableNodeData) = vnd.value
get_context(vnd::VariableNodeData) = vnd.context

# Constants for variable kinds
const VariableKindRandom = :random
const VariableKindData = :data
const VariableKindConstant = :constant
const VariableKindUnknown = :unknown
const VariableNameAnonymous = :anonymous_var_graphppl

# Kind-based functions
is_kind(vnd::VariableNodeData, kind) = vnd.kind === kind
is_kind(vnd::VariableNodeData, ::Val{kind}) where {kind} = vnd.kind === kind
is_random(vnd::VariableNodeData) = is_kind(vnd, Val(VariableKindRandom))
is_data(vnd::VariableNodeData) = is_kind(vnd, Val(VariableKindData))
is_constant(vnd::VariableNodeData) = is_kind(vnd, Val(VariableKindConstant))
is_anonymous(vnd::VariableNodeData) = vnd.name === VariableNameAnonymous

# Extra properties management
has_extra(vnd::VariableNodeData, key) = haskey(vnd.extras, key)

function get_extra(vnd::VariableNodeData, key)
    if !has_extra(vnd, key)
        throw(KeyError(key))
    end
    return vnd.extras[key]
end

function get_extra(vnd::VariableNodeData, key, default)
    return has_extra(vnd, key) ? vnd.extras[key] : default
end

function get_extra(vnd::VariableNodeData)
    return vnd.extras
end

function set_extra!(vnd::VariableNodeData, key, value)
    vnd.extras[key] = value
    return vnd
end

# Custom show method
function Base.show(io::IO, vnd::VariableNodeData)
    kind_str = if is_random(vnd)
        "random"
    elseif is_data(vnd)
        "data"
    elseif is_constant(vnd)
        "constant"
    else
        string(vnd.kind)
    end

    print(io, "VariableNodeData(name=:$(vnd.name), kind=:$(kind_str))")
end
