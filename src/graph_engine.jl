using MetaGraphsNext, MetaGraphsNext.Graphs
using BitSetTuples
using Static
using NamedTupleTools
using Dictionaries

import Base: put!, haskey, gensym, getindex, getproperty, setproperty!, setindex!, vec, iterate
import MetaGraphsNext.Graphs: neighbors, degree

export as_node, as_variable, as_context

aliases(f) = (f,)

struct Broadcasted
    name::Symbol
end

getname(broadcasted::Broadcasted) = broadcasted.name

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
    FunctionalIndex(collection)

Returns the result of applying the function `f` to the collection.
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
    IndexedVariable

`IndexedVariable` represents a reference to a variable named `name` with index `index`. 
An IndexedVariable is generally part of a vector or tensor of random variables.
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

struct FactorID
    fform::Any
    index::Int64
end

fform(id::FactorID) = id.fform
index(id::FactorID) = id.index

Base.show(io::IO, id::FactorID) = print(io, "(", fform(id), ", ", index(id), ")")

"""
    Model(graph::MetaGraph)

Materialized Factor Graph type.

A structure representing a probabilistic graphical model. It contains a `MetaGraph` object
representing the factor graph and a `Base.RefValue{Int64}` object to keep track of the number
of nodes in the graph.

Fields:
- `graph`: A `MetaGraph` object representing the factor graph.
- `plugins`: A `PluginCollection` object representing the plugins enabled in the model.
- `counter`: A `Base.RefValue{Int64}` object keeping track of the number of nodes in the graph.
"""
struct Model{G, P}
    graph::G
    plugins::P
    counter::Base.RefValue{Int64}
end

labels(model::Model) = MetaGraphsNext.labels(model.graph)
Base.isempty(model::Model) = iszero(nv(model.graph)) && iszero(ne(model.graph))

getplugins(model::Model) = model.plugins

"""
    NodeLabel(name::Symbol, global_counter::Int64)

Unique identifier for a node in a probabilistic graphical model.

A structure representing a node in a probabilistic graphical model. It contains a symbol
representing the name of the node, an integer representing the unique identifier of the node,
a UInt8 representing the type of the variable, and an integer or tuple of integers representing
the global_counter of the variable.
"""
struct NodeLabel
    name::Any
    global_counter::Int64
end

Base.length(label::NodeLabel) = 1
Base.getindex(label::NodeLabel, any) = label
Base.:(<)(left::NodeLabel, right::NodeLabel) = left.global_counter < right.global_counter

getname(label::NodeLabel) = label.name
getname(labels::ResizableArray{T, V, N} where {T <: NodeLabel, V, N}) = getname(first(labels))
iterate(label::NodeLabel) = (label, nothing)
iterate(label::NodeLabel, any) = nothing

to_symbol(label::NodeLabel) = Symbol(String(label.name) * "_" * string(label.global_counter))

Base.show(io::IO, label::NodeLabel) = print(io, label.name, "_", label.global_counter)

struct EdgeLabel
    name::Symbol
    index::Union{Int, Nothing}
end

getname(label::EdgeLabel) = label.name
getname(labels::Tuple) = map(group -> getname(group), labels)

to_symbol(label::EdgeLabel) = to_symbol(label, label.index)
to_symbol(label::EdgeLabel, ::Nothing) = label.name
to_symbol(label::EdgeLabel, ::Int64) = Symbol(string(label.name) * "[" * string(label.index) * "]")

Base.show(io::IO, label::EdgeLabel) = print(io, to_symbol(label))

struct ProxyLabel{T, V}
    name::Symbol
    index::T
    proxied::V
end

# We need two methods to resolve the ambiguities
proxylabel(name::Symbol, index::Nothing, proxied::Union{NodeLabel, ProxyLabel, ResizableArray{NodeLabel}}) =
    ProxyLabel(name, index, proxied)
proxylabel(name::Symbol, index::Tuple, proxied::Union{NodeLabel, ProxyLabel, ResizableArray{NodeLabel}}) = ProxyLabel(name, index, proxied)

# By default we assume that the `proxied` is just a constant here, so
# in case if 
# - `index` is a `nothing` we simply return the constant as it is
# - `index` is a `Tuple` we return the constant indexed by the tuple
proxylabel(name::Symbol, index::Nothing, proxied) = proxied
proxylabel(name::Symbol, index::Tuple, proxied) = proxied[index...]

getname(label::ProxyLabel) = label.name
index(label::ProxyLabel) = label.index

unroll(proxy::ProxyLabel) = __proxy_unroll(proxy)
unroll(something) = something

__proxy_unroll(something) = something
__proxy_unroll(proxy::ProxyLabel) = __proxy_unroll(proxy, proxy.index, proxy.proxied)
__proxy_unroll(proxy::ProxyLabel, index, proxied) = __safegetindex(__proxy_unroll(proxied), index)

__safegetindex(something, index::FunctionalIndex) = Base.getindex(something, index)
__safegetindex(something, index::Tuple) = Base.getindex(something, index...)
__safegetindex(something, index::Nothing) = something

__safegetindex(nodelabel::NodeLabel, index::Nothing) = nodelabel
__safegetindex(nodelabel::NodeLabel, index::Tuple) =
    error("Indexing a single node label `$(getname(nodelabel))` with an index `[$(join(index, ", "))]` is not allowed.")
__safegetindex(nodelabel::NodeLabel, index) =
    error("Indexing a single node label `$(getname(nodelabel))` with an index `$index` is not allowed.")

Base.show(io::IO, proxy::ProxyLabel{NTuple{N, Int}} where {N}) = print(io, getname(proxy), "[", index(proxy), "]")
Base.show(io::IO, proxy::ProxyLabel{Nothing}) = print(io, getname(proxy))
Base.show(io::IO, proxy::ProxyLabel) = print(io, getname(proxy), "[", index(proxy)[1], "]")
Base.getindex(proxy::ProxyLabel, indices...) = getindex(unroll(proxy), indices...)

Base.last(label::ProxyLabel) = last(label.proxied, label)

Base.last(proxied::ProxyLabel, ::ProxyLabel) = last(proxied)
Base.last(proxied, ::ProxyLabel) = proxied

"""
    Context

Contains all information about a submodel in a probabilistic graphical model.
"""
struct Context
    depth::Int64
    fform::Function
    prefix::String
    parent::Union{Context, Nothing}
    submodel_counts::UnorderedDictionary{Any, Int}
    children::UnorderedDictionary{FactorID, Context}
    factor_nodes::UnorderedDictionary{FactorID, NodeLabel}
    individual_variables::UnorderedDictionary{Symbol, NodeLabel}
    vector_variables::UnorderedDictionary{Symbol, ResizableArray{NodeLabel, Vector{NodeLabel}, 1}}
    tensor_variables::UnorderedDictionary{Symbol, ResizableArray{NodeLabel}}
    proxies::UnorderedDictionary{Symbol, ProxyLabel}
end

function Context(depth::Int, fform::Function, prefix::String, parent)
    return Context(
        depth,
        fform,
        prefix,
        parent,
        UnorderedDictionary{Any, Int}(),
        UnorderedDictionary{FactorID, Context}(),
        UnorderedDictionary{FactorID, NodeLabel}(),
        UnorderedDictionary{Symbol, NodeLabel}(),
        UnorderedDictionary{Symbol, ResizableArray{NodeLabel, Vector{NodeLabel}, 1}}(),
        UnorderedDictionary{Symbol, ResizableArray{NodeLabel}}(),
        UnorderedDictionary{Symbol, ProxyLabel}()
    )
end

Context(parent::Context, model_fform::Function) =
    Context(parent.depth + 1, model_fform, (parent.prefix == "" ? parent.prefix : parent.prefix * "_") * getname(model_fform), parent)
Context(fform) = Context(0, fform, "", nothing)
Context() = Context(identity)

fform(context::Context) = context.fform
parent(context::Context) = context.parent
individual_variables(context::Context) = context.individual_variables
vector_variables(context::Context) = context.vector_variables
tensor_variables(context::Context) = context.tensor_variables
factor_nodes(context::Context) = context.factor_nodes
proxies(context::Context) = context.proxies
children(context::Context) = context.children
count(context::Context, fform::F) where {F} = haskey(context.submodel_counts, fform) ? context.submodel_counts[fform] : 0
shortname(context::Context) = string(context.prefix)

path_to_root(::Nothing) = []
path_to_root(context::Context) = [context, path_to_root(parent(context))...]

function generate_factor_nodelabel(context::Context, fform::F) where {F}
    if count(context, fform) == 0
        set!(context.submodel_counts, fform, 1)
    else
        context.submodel_counts[fform] += 1
    end
    return FactorID(fform, count(context, fform))
end

function Base.show(io::IO, mime::MIME"text/plain", context::Context)
    iscompact = get(io, :compact, false)::Bool

    if iscompact
        print(io, "Context(", shortname(context), " | ")
        nvariables =
            length(context.individual_variables) +
            length(context.vector_variables) +
            length(context.tensor_variables) +
            length(context.proxies)
        nfactornodes = length(context.factor_nodes)
        print(io, nvariables, " variables, ", nfactornodes, " factor nodes")
        if !isempty(context.children)
            print(io, ", ", length(context.children), " children")
        end
        print(io, ")")
    else
        indentation = get(io, :indentation, 0)::Int
        indentationstr = " "^indentation
        indentationstrp1 = " "^(indentation + 1)
        println(io, indentationstr, "Context(", shortname(context), ")")
        println(io, indentationstrp1, "Individual variables: ", keys(individual_variables(context)))
        println(io, indentationstrp1, "Vector variables: ", keys(vector_variables(context)))
        println(io, indentationstrp1, "Tensor variables: ", keys(tensor_variables(context)))
        println(io, indentationstrp1, "Proxies: ", keys(proxies(context)))
        println(io, indentationstrp1, "Factor nodes: ", collect(keys(factor_nodes(context))))
        if !isempty(context.children)
            println(io, indentationstrp1, "Children: ", map(shortname, values(context.children)))
        end
    end
end

getname(f::Function) = String(Symbol(f))

haskey(context::Context, key::Symbol) =
    haskey(context.individual_variables, key) ||
    haskey(context.vector_variables, key) ||
    haskey(context.tensor_variables, key) ||
    haskey(context.proxies, key)

haskey(context::Context, key::FactorID) = haskey(context.factor_nodes, key) || haskey(context.children, key)

function Base.getindex(c::Context, key::Symbol)
    if haskey(c.individual_variables, key)
        return c.individual_variables[key]
    elseif haskey(c.vector_variables, key)
        return c.vector_variables[key]
    elseif haskey(c.tensor_variables, key)
        return c.tensor_variables[key]
    elseif haskey(c.proxies, key)
        return c.proxies[key]
    end
    throw(KeyError(key))
end

function Base.getindex(c::Context, key::FactorID)
    if haskey(c.factor_nodes, key)
        return c.factor_nodes[key]
    elseif haskey(c.children, key)
        return c.children[key]
    end
    throw(KeyError(key))
end

Base.getindex(c::Context, fform, index::Int) = c[FactorID(fform, index)]

Base.setindex!(c::Context, val::NodeLabel, key::Symbol) = set!(c.individual_variables, key, val)
Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::Nothing) = set!(c.individual_variables, key, val)
Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::Int) = c.vector_variables[key][index] = val
Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::NTuple{N, Int64} where {N}) = c.tensor_variables[key][index...] = val
Base.setindex!(c::Context, val::ResizableArray{NodeLabel, T, 1} where {T}, key::Symbol) = set!(c.vector_variables, key, val)
Base.setindex!(c::Context, val::ResizableArray{NodeLabel, T, N} where {T, N}, key::Symbol) = set!(c.tensor_variables, key, val)
Base.setindex!(c::Context, val::ProxyLabel, key::Symbol) = set!(c.proxies, key, val)
Base.setindex!(c::Context, val::ProxyLabel, key::Symbol, index::Nothing) = set!(c.proxies, key, val)
Base.setindex!(c::Context, val::Context, key::FactorID) = set!(c.children, key, val)
Base.setindex!(c::Context, val::NodeLabel, key::FactorID) = set!(c.factor_nodes, key, val)

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

"""
    NodeCreationOptions(namedtuple)

Options for creating a node in a probabilistic graphical model. These are typically coming from the `where {}` block 
in the `@model` macro, but can also be created manually. Expects a `NamedTuple` as an input.
"""
struct NodeCreationOptions{N}
    options::N
end

const EmptyNodeCreationOptions = NodeCreationOptions{Nothing}(nothing)

NodeCreationOptions(; kwargs...) = convert(NodeCreationOptions, kwargs)

Base.convert(::Type{NodeCreationOptions}, ::@Kwargs{}) = NodeCreationOptions(nothing)
Base.convert(::Type{NodeCreationOptions}, options) = NodeCreationOptions(NamedTuple(options))

Base.haskey(options::NodeCreationOptions, key::Symbol) = haskey(options.options, key)
Base.getindex(options::NodeCreationOptions, keys...) = getindex(options.options, keys...)
Base.getindex(options::NodeCreationOptions, keys::NTuple{N, Symbol}) where {N} = NodeCreationOptions(getindex(options.options, keys))
Base.keys(options::NodeCreationOptions) = keys(options.options)
Base.get(options::NodeCreationOptions, key::Symbol, default) = get(options.options, key, default)

# Fast fallback for empty options
Base.haskey(::NodeCreationOptions{Nothing}, key::Symbol) = false
Base.getindex(::NodeCreationOptions{Nothing}, keys...) = error("type `NodeCreationOptions{Nothing}` has no field $(keys)")
Base.keys(::NodeCreationOptions{Nothing}) = ()
Base.get(::NodeCreationOptions{Nothing}, key::Symbol, default) = default

withopts(::NodeCreationOptions{Nothing}, options::NamedTuple) = NodeCreationOptions(options)
withopts(options::NodeCreationOptions, extra::NamedTuple) = NodeCreationOptions((; options.options..., extra...))

withoutopts(::NodeCreationOptions{Nothing}, ::Val) = NodeCreationOptions(nothing)

function withoutopts(options::NodeCreationOptions, ::Val{K}) where {K}
    newoptions = options.options[filter(key -> key ∉ K, keys(options.options))]
    # Should be compiled out, there are tests for it
    if isempty(newoptions)
        return NodeCreationOptions(nothing)
    else
        return NodeCreationOptions(newoptions)
    end
end

struct VariableNodeProperties
    name::Symbol
    index::Any
    kind::Symbol
    link::Any
    value::Any
end

VariableNodeProperties(; name, index, kind = :random, link = nothing, value = nothing) =
    VariableNodeProperties(name, index, kind, link, value)

is_factor(::VariableNodeProperties)   = false
is_variable(::VariableNodeProperties) = true

function Base.convert(::Type{VariableNodeProperties}, name::Symbol, index, options::NodeCreationOptions)
    return VariableNodeProperties(
        name = name,
        index = index,
        kind = get(options, :kind, :random),
        link = get(options, :link, nothing),
        value = get(options, :value, nothing)
    )
end

getname(properties::VariableNodeProperties) = properties.name
getlink(properties::VariableNodeProperties) = properties.link
index(properties::VariableNodeProperties) = properties.index
value(properties::VariableNodeProperties) = properties.value

is_kind(properties::VariableNodeProperties, kind) = properties.kind === kind
is_kind(properties::VariableNodeProperties, ::Val{kind}) where {kind} = properties.kind === kind
is_random(properties::VariableNodeProperties) = is_kind(properties, Val(:random))
is_data(properties::VariableNodeProperties) = is_kind(properties, Val(:data))
is_constant(properties::VariableNodeProperties) = is_kind(properties, Val(:constant))

function Base.show(io::IO, properties::VariableNodeProperties)
    print(io, "name = ", properties.name, ", index = ", properties.index)
    if !isnothing(properties.link)
        print(io, "(linked to ", node.link, ")")
    end
end

"""
    FactorNodeProperties(fform, neighbours)

Data associated with a factor node in a probabilistic graphical model.
"""
struct FactorNodeProperties
    fform::Any
    neighbors::Vector{Tuple{NodeLabel, EdgeLabel, Any}}
end

FactorNodeProperties(; fform, neighbors = Tuple{NodeLabel, EdgeLabel}[]) = FactorNodeProperties(fform, neighbors)

is_factor(::FactorNodeProperties)   = true
is_variable(::FactorNodeProperties) = false

function Base.convert(::Type{FactorNodeProperties}, fform, options::NodeCreationOptions)
    return FactorNodeProperties(fform = fform, neighbors = get(options, :neighbors, Tuple{NodeLabel, EdgeLabel}[]))
end

fform(properties::FactorNodeProperties) = properties.fform
neighbors(properties::FactorNodeProperties) = properties.neighbors
addneighbor!(properties::FactorNodeProperties, variable::NodeLabel, edge::EdgeLabel, data::F) where {F} = push!(properties.neighbors, (variable, edge, data))
neighbor_data(properties::FactorNodeProperties) = Iterators.map(neighbor -> neighbor[3], neighbors(properties))

function Base.show(io::IO, properties::FactorNodeProperties)
    print(io, "fform = ", properties.fform, ", neighbors = ", properties.neighbors)
end

"""
    NodeData(context, properties, plugins)

Data associated with a node in a probabilistic graphical model. 
The `context` field stores the context of the node. 
The `properties` field stores the properties of the node. 
The `plugins` field stores additional properties of the node depending on which plugins were enabled.
"""
struct NodeData
    context    :: Context
    properties :: Union{VariableNodeProperties, FactorNodeProperties}
    extra      :: UnorderedDictionary{Symbol, Any}
end

NodeData(context, properties) = NodeData(context, properties, UnorderedDictionary{Symbol, Any}())

function Base.show(io::IO, nodedata::NodeData)
    context = getcontext(nodedata)
    properties = getproperties(nodedata)
    print(io, "NodeData in context ", shortname(context), " with properties ", properties)
    extra = getextra(nodedata)
    if !isempty(extra)
        print(io, " with extra: ")
        print(io, extra)
    end
end

getcontext(node::NodeData)    = node.context
getproperties(node::NodeData) = node.properties
getextra(node::NodeData)      = node.extra

hasextra(node::NodeData, key::Symbol) = haskey(node.extra, key)
getextra(node::NodeData, key::Symbol) = getindex(node.extra, key)
setextra!(node::NodeData, key::Symbol, value) = insert!(node.extra, key, value)

is_factor(node::NodeData)   = is_factor(getproperties(node))
is_variable(node::NodeData) = is_variable(getproperties(node))

factor_nodes(model::Model)   = Iterators.filter(node -> is_factor(model[node]), labels(model))
variable_nodes(model::Model) = Iterators.filter(node -> is_variable(model[node]), labels(model))

"""
A version `factor_nodes(model)` that uses a callback function to process the factor  nodes.
The callback function accepts both the label and the node data.
"""
function factor_nodes(callback::F, model::Model) where {F}
    for label in labels(model)
        nodedata = model[label]
        if is_factor(nodedata)
            callback((label::NodeLabel), (nodedata::NodeData))
        end
    end
end

"""
A version `variable_nodes(model)` that uses a callback function to process the variable nodes.
The callback function accepts both the label and the node data.
"""
function variable_nodes(callback::F, model::Model) where {F}
    for label in labels(model)
        nodedata = model[label]
        if is_variable(nodedata)
            callback((label::NodeLabel), (nodedata::NodeData))
        end
    end
end

"""
A structure that holds interfaces of a node in the type argument `I`. Used for dispatch.
"""
struct StaticInterfaces{I} end

StaticInterfaces(I::Tuple) = StaticInterfaces{I}()
Base.getindex(::StaticInterfaces{I}, index) where {I} = I[index]

Model(graph::MetaGraph) = Model(graph, PluginsCollection())

function Model(graph::MetaGraph, plugins::PluginsCollection)
    return Model(graph, plugins, Base.RefValue(0))
end

Base.setindex!(model::Model, val::NodeData, key::NodeLabel) = Base.setindex!(model.graph, val, key)
Base.setindex!(model::Model, val::EdgeLabel, src::NodeLabel, dst::NodeLabel) = Base.setindex!(model.graph, val, src, dst)
Base.getindex(model::Model) = Base.getindex(model.graph)
Base.getindex(model::Model, key::NodeLabel) = Base.getindex(model.graph, key)
Base.getindex(model::Model, src::NodeLabel, dst::NodeLabel) = Base.getindex(model.graph, src, dst)
Base.getindex(model::Model, keys::AbstractArray{NodeLabel}) = map(key -> model[key], keys)
Base.getindex(model::Model, keys::NTuple{N, NodeLabel}) where {N} = collect(map(key -> model[key], keys))

Base.getindex(model::Model, keys::Base.Generator) = [model[key] for key in keys]

function Base.getproperty(val::Model, p::Symbol)
    if p === :counter
        return getfield(val, :counter)[]
    else
        return getfield(val, p)
    end
end

function Base.setproperty!(val::Model, p::Symbol, new_count)
    if p === :counter
        return getfield(val, :counter)[] = new_count
    else
        return setfield!(val, p, x)
    end
end

increase_count(model::Model) = Base.setproperty!(model, :counter, model.counter + 1)

Graphs.nv(model::Model) = Graphs.nv(model.graph)
Graphs.ne(model::Model) = Graphs.ne(model.graph)
Graphs.edges(model::Model) = Graphs.edges(model.graph)

Graphs.neighbors(model::Model, node::NodeLabel)                   = Graphs.neighbors(model, node, model[node])
Graphs.neighbors(model::Model, nodes::AbstractArray{<:NodeLabel}) = Iterators.flatten(map(node -> Graphs.neighbors(model, node), nodes))

Graphs.neighbors(model::Model, node::NodeLabel, nodedata::NodeData)                                     = Graphs.neighbors(model, node, nodedata, getproperties(nodedata))
Graphs.neighbors(model::Model, node::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties)   = map(neighbor -> neighbor[1], neighbors(properties))
Graphs.neighbors(model::Model, node::NodeLabel, nodedata::NodeData, properties::VariableNodeProperties) = MetaGraphsNext.neighbor_labels(model.graph, node)

Graphs.edges(model::Model, node::NodeLabel) = Graphs.edges(model, node, model[node])
Graphs.edges(model::Model, nodes::AbstractArray{<:NodeLabel}) = Iterators.flatten(map(node -> Graphs.edges(model, node), nodes))

Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData) = Graphs.edges(model, node, nodedata, getproperties(nodedata))
Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties) =
    map(neighbor -> neighbor[2], neighbors(properties))

function Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::VariableNodeProperties)
    return (model[node, dst] for dst in MetaGraphsNext.neighbor_labels(model.graph, node))
end

Graphs.degree(model::Model, label::NodeLabel) = Graphs.degree(model.graph, MetaGraphsNext.code_for(model.graph, label))

abstract type AbstractModelFilterPredicate end

struct FactorNodePredicate{N} <: AbstractModelFilterPredicate end

function apply(::FactorNodePredicate{N}, model, something) where {N}
    return apply(IsFactorNode(), model, something) && fform(getproperties(model[something])) ∈ aliases(N)
end

struct IsFactorNode <: AbstractModelFilterPredicate end

function apply(::IsFactorNode, model, something)
    return is_factor(model[something])
end

struct VariableNodePredicate{V} <: AbstractModelFilterPredicate end

function apply(::VariableNodePredicate{N}, model, something) where {N}
    return apply(IsVariableNode(), model, something) && getname(getproperties(model[something])) === N
end

struct IsVariableNode <: AbstractModelFilterPredicate end

function apply(::IsVariableNode, model, something)
    return is_variable(model[something])
end

struct SubmodelPredicate{S, C} <: AbstractModelFilterPredicate end

function apply(::SubmodelPredicate{S, False}, model, something) where {S}
    return fform(getcontext(model[something])) === S
end

function apply(::SubmodelPredicate{S, True}, model, something) where {S}
    return S ∈ fform.(path_to_root(getcontext(model[something])))
end

struct AndNodePredicate{L, R} <: AbstractModelFilterPredicate
    left::L
    right::R
end

function apply(and::AndNodePredicate, model, something)
    return apply(and.left, model, something) && apply(and.right, model, something)
end

struct OrNodePredicate{L, R} <: AbstractModelFilterPredicate
    left::L
    right::R
end

function apply(or::OrNodePredicate, model, something)
    return apply(or.left, model, something) || apply(or.right, model, something)
end

Base.:(|)(left::AbstractModelFilterPredicate, right::AbstractModelFilterPredicate) = OrNodePredicate(left, right)
Base.:(&)(left::AbstractModelFilterPredicate, right::AbstractModelFilterPredicate) = AndNodePredicate(left, right)

as_node(any) = FactorNodePredicate{any}()
as_node() = IsFactorNode()
as_variable(any) = VariableNodePredicate{any}()
as_variable() = IsVariableNode()
as_context(any; children = false) = SubmodelPredicate{any, typeof(static(children))}()

function Base.filter(predicate::AbstractModelFilterPredicate, model::Model)
    return Iterators.filter(something -> apply(predicate, model, something), labels(model))
end

"""
    generate_nodelabel(model::Model, name::Symbol)

Generate a new `NodeLabel` object with a unique identifier based on the specified name and the
number of nodes already in the model.

Arguments:
- `model`: A `Model` object representing the probabilistic graphical model.
- `name`: A symbol representing the name of the node.
- `variable_type`: A UInt8 representing the type of the variable. 0 = factor, 1 = individual variable, 2 = vector variable, 3 = tensor variable
- `index`: An integer or tuple of integers representing the index of the variable.

Returns:
"""
function generate_nodelabel(model::Model, name)
    increase_count(model)
    return NodeLabel(name, model.counter)
end

function Base.gensym(model::Model, name::Symbol)
    increase_count(model)
    return Symbol(String(name) * "_" * string(model.counter))
end

"""
    getcontext(model::Model)

Retrieves the context of a model. The context of a model contains the complete hierarchy of variables and factor nodes. 
Additionally, contains all child submodels and their respective contexts. The Context supplies a mapping from symbols to `GraphPPL.NodeLabel` structures
with which the model can be queried.
"""
getcontext(model::Model) = model[]

function get_principal_submodel(model::Model)
    context = getcontext(model)
    return context
end

Base.getindex(context::Context, ivar::IndexedVariable{Nothing}) = context[getname(ivar)]
Base.getindex(context::Context, ivar::IndexedVariable) = context[getname(ivar)][index(ivar)]

abstract type NodeType end

struct Composite <: NodeType end
struct Atomic <: NodeType end

NodeType(::Type) = Atomic()
NodeType(::F) where {F<:Function} = Atomic()

abstract type NodeBehaviour end

struct Stochastic <: NodeBehaviour end
struct Deterministic <: NodeBehaviour end

NodeBehaviour(::Any) = Deterministic()

"""
create_model()

Create a new empty probabilistic graphical model. 

Returns:
A `Model` object representing the probabilistic graphical model.
"""
function create_model(; fform = identity, plugins = PluginsCollection())
    label_type = NodeLabel
    edge_data_type = EdgeLabel
    vertex_data_type = NodeData
    graph = MetaGraph(Graph(), label_type, vertex_data_type, edge_data_type, Context(fform))
    model = Model(graph, plugins)
    return model
end

"""
copy_markov_blanket_to_child_context(child_context::Context, interfaces::NamedTuple)

Copy the variables in the Markov blanket of a parent context to a child context, using a mapping specified by a named tuple.

The Markov blanket of a node or model in a Factor Graph is defined as the set of its outgoing interfaces. 
This function copies the variables in the Markov blanket of the parent context specified by the named tuple `interfaces` to the child context `child_context`, 
    by setting each child variable in `child_context.individual_variables` to its corresponding parent variable in `interfaces`.

# Arguments
- `child_context::Context`: The child context to which to copy the Markov blanket variables.
- `interfaces::NamedTuple`: A named tuple that maps child variable names to parent variable names.
"""
function copy_markov_blanket_to_child_context(child_context::Context, interfaces::NamedTuple)
    for (name_in_child, object_in_parent) in iterator(interfaces)
        add_to_child_context(child_context, name_in_child, object_in_parent)
    end
end

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::NodeLabel) =
    set!(child_context.individual_variables, name_in_child, object_in_parent)

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ResizableArray{NodeLabel, V, 1}) where {V} =
    set!(child_context.vector_variables, name_in_child, object_in_parent)

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ResizableArray{NodeLabel, V, N}) where {V, N} =
    set!(child_context.tensor_variables, name_in_child, object_in_parent)

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ProxyLabel) =
    set!(child_context.proxies, name_in_child, object_in_parent)

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent) = nothing

throw_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ? error("Variable $name is already an individual variable in the model") : nothing
throw_if_vector_variable(context::Context, name::Symbol) =
    haskey(context.vector_variables, name) ? error("Variable $name is already a vector variable in the model") : nothing
throw_if_tensor_variable(context::Context, name::Symbol) =
    haskey(context.tensor_variables, name) ? error("Variable $name is already a tensor variable in the model") : nothing

""" 
    check_variate_compatability(node, index)

Will check if the index is compatible with the node object that is passed.

"""
check_variate_compatability(node::NodeLabel, index::Nothing) = true
check_variate_compatability(node::NodeLabel, index) =
    error("Cannot call single random variable on the left-hand-side by an indexed statement")

check_variate_compatability(label::GraphPPL.ProxyLabel, index) = check_variate_compatability(unroll(label), index)

function check_variate_compatability(node::ResizableArray{NodeLabel, V, N}, index...) where {V, N}
    if !(length(index) == N)
        error("Index of length $(length(index)) not possible for $N-dimensional vector of random variables")
    end
    return isassigned(node, index...)
end

check_variate_compatability(node::ResizableArray{NodeLabel, V, N}, index::Nothing) where {V, N} =
    error("Cannot call vector of random variables on the left-hand-side by an unindexed statement")

"""
    getorcreate!(model::Model, context::Context, options::NodeCreationOptions, name, index)

Get or create a variable (name) from a factor graph model and context, using an index if provided.

This function searches for a variable (name) in the factor graph model and context specified by the arguments `model` and `context`. If the variable exists, 
it returns it. Otherwise, it creates a new variable and returns it.

# Arguments
- `model::Model`: The factor graph model to search for or create the variable in.
- `context::Context`: The context to search for or create the variable in.
- `name`: The variable (name) to search for or create. Must be a symbol.
- `index`: Optional index for the variable. Can be an integer, a tuple of integers, or `nothing`.

# Returns
The variable (name) found or created in the factor graph model and context.
"""
function getorcreate! end

getorcreate!(::Model, ::Context, name::Symbol) = error("Index is required in the `getorcreate!` function for variable `$(name)`")
getorcreate!(::Model, ::Context, options::NodeCreationOptions, name::Symbol) =
    error("Index is required in the `getorcreate!` function for variable `$(name)`")

function getorcreate!(model::Model, ctx::Context, name::Symbol, index...)
    return getorcreate!(model, ctx, EmptyNodeCreationOptions, name, index...)
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index::Nothing)
    throw_if_vector_variable(ctx, name)
    throw_if_tensor_variable(ctx, name)
    return get(() -> add_variable_node!(model, ctx, options, name, index), ctx.individual_variables, name)
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index::Integer)
    throw_if_individual_variable(ctx, name)
    throw_if_tensor_variable(ctx, name)
    if !haskey(ctx.vector_variables, name)
        ctx[name] = ResizableArray(NodeLabel, Val(1))
    end
    vectorvar = ctx.vector_variables[name]
    if !isassigned(vectorvar, index)
        vectorvar[index] = add_variable_node!(model, ctx, options, name, index)
    end
    return vectorvar
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, i1::Integer, is::Vararg{Integer})
    throw_if_individual_variable(ctx, name)
    throw_if_vector_variable(ctx, name)
    if !haskey(ctx.tensor_variables, name)
        ctx[name] = ResizableArray(NodeLabel, Val(1 + length(is)))
    end
    tensorvar = ctx.tensor_variables[name]
    if !isassigned(tensorvar, i1, is...)
        tensorvar[i1, is...] = add_variable_node!(model, ctx, options, name, (i1, is...))
    end
    return tensorvar
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, range::AbstractRange)
    isempty(range) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(range) do i
        getorcreate!(model, ctx, options, name, i)
    end
    return getorcreate!(model, ctx, options, name, first(range))
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, r1::AbstractRange, rs::Vararg{AbstractRange})
    (isempty(r1) || any(isempty, rs)) && error("Empty range is not allowed in the `getorcreate!` function for variable `$(name)`")
    foreach(Iterators.product(r1, rs...)) do i
        getorcreate!(model, ctx, options, name, i...)
    end
    return getorcreate!(model, ctx, options, name, first(r1), first.(rs)...)
end

getifcreated(model::Model, context::Context, var::NodeLabel) = var
getifcreated(model::Model, context::Context, var::ResizableArray) = var
getifcreated(model::Model, context::Context, var::Union{Tuple, AbstractArray{NodeLabel}}) = map((v) -> getifcreated(model, context, v), var)
getifcreated(model::Model, context::Context, var::ProxyLabel) = var

getifcreated(model::Model, context::Context, var) =
    add_variable_node!(model, context, NodeCreationOptions(value = var, kind = :constant), gensym(model, :constvar), nothing)

"""
`LazyIndex` is used to track the usage of a variable in the model without explicitly specifying its dimensions.
`getorcreate!` function will return a `LazyNodeLabel` which will materialize itself upon first usage with the correct dimensions.
E.g. `y[1]` will materialize vector variable `y` and `y[1, 1]` will materialize tensor variable `y`.
Optionally the `LazyIndex` can be associated with a `collection`, in which case it not only redirects most of the common 
collection methods to the underlying collection, but also checks that the dimensions and usage match of such labels in the model specification is correct.
"""
struct LazyIndex{C}
    collection::C
end

struct MissingCollection end

__err_missing_collection_missing_method(method::Symbol) =
    error("The `$method` method is not defined for a lazy node label without data attached.")

Base.IteratorSize(::Type{MissingCollection}) = __err_missing_collection_missing_method(:IteratorSize)
Base.IteratorEltype(::Type{MissingCollection}) = __err_missing_collection_missing_method(:IteratorEltype)
Base.eltype(::Type{MissingCollection}) = __err_missing_collection_missing_method(:eltype)
Base.length(::MissingCollection) = __err_missing_collection_missing_method(:length)
Base.size(::MissingCollection, dims...) = __err_missing_collection_missing_method(:size)
Base.firstindex(::MissingCollection) = __err_missing_collection_missing_method(:firstindex)
Base.lastindex(::MissingCollection) = __err_missing_collection_missing_method(:lastindex)
Base.eachindex(::MissingCollection) = __err_missing_collection_missing_method(:eachindex)
Base.axes(::MissingCollection) = __err_missing_collection_missing_method(:axes)

LazyIndex() = LazyIndex(MissingCollection())

getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index::LazyIndex) =
    LazyNodeLabel(model, ctx, options, name, index.collection)

"""
`LazyNodeLabel` is a label that lazily creates variables upon request in the `proxylabel` function.
"""
struct LazyNodeLabel{O, C}
    model::Model
    context::Context
    options::O
    name::Symbol
    collection::C
end

check_variate_compatability(label::LazyNodeLabel, indices...) =
    __lazy_node_label_check_variate_compatability(label, label.collection, indices)

# Redirect some of the standard collection methods to the underlying collection
Base.IteratorSize(::Type{LazyNodeLabel{O, C}}) where {O, C} = Base.IteratorSize(C)
Base.IteratorEltype(::Type{LazyNodeLabel{O, C}}) where {O, C} = Base.IteratorEltype(C)
Base.eltype(::Type{LazyNodeLabel{O, C}}) where {O, C} = Base.eltype(C)
Base.length(label::LazyNodeLabel) = Base.length(label.collection)
Base.size(label::LazyNodeLabel, dims...) = Base.size(label.collection, dims...)
Base.firstindex(label::LazyNodeLabel) = Base.firstindex(label.collection)
Base.lastindex(label::LazyNodeLabel) = Base.lastindex(label.collection)
Base.eachindex(label::LazyNodeLabel) = Base.eachindex(label.collection)
Base.axes(label::LazyNodeLabel) = Base.axes(label.collection)

function __lazy_iterator(label::LazyNodeLabel)
    return Iterators.map(I -> materialize_lazy_node_label(label, I.I), CartesianIndices(axes(label)))
end

function Base.iterate(label::LazyNodeLabel)
    iterator = __lazy_iterator(label)
    nextiteration = Base.iterate(iterator)
    if isnothing(nextiteration)
        return nothing
    end
    element, nextstate = nextiteration
    return (element, (iterator, nextstate))
end

function Base.iterate(::LazyNodeLabel, state)
    iterator, currentstate = state
    nextiteration = Base.iterate(iterator, currentstate)
    if isnothing(nextiteration)
        return nothing
    end
    element, nextstate = nextiteration
    return (element, (iterator, nextstate))
end

# We cannot really check any `indices` if the underlying collection is missing 
__lazy_node_label_check_variate_compatability(label::LazyNodeLabel, collection::MissingCollection, indices) = true

# Here we can check if the `indices` are compatible with the underlying collection
function __lazy_node_label_check_variate_compatability(label::LazyNodeLabel, collection, indices)
    if !(checkbounds(Bool, collection, indices...)::Bool)
        error(BoundsError(label.name, indices))
    end
    return true
end

# A `ProxyLabel` with a `LazyNodeLabel` as a proxied variable unrolls to an actual variable upon usage with the `getorcreate!` function
# This means that the `LazyNodeLabel` will materialize itself upon first usage with the correct dimensions.
# Note: Need two methods here because of the method ambiguity
proxylabel(name::Symbol, index::Nothing, proxied::LazyNodeLabel) = ProxyLabel(name, index, proxied)
proxylabel(name::Symbol, index::Tuple, proxied::LazyNodeLabel) = ProxyLabel(name, index, proxied)

# We disallow that because all accesses to the `LazyNodeLabel` should create a real label instead
getifcreated(::Model, ::Context, ::LazyNodeLabel) = error("`getifcreated` cannot be called on a `LazyNodeLabel`")

materialize_interface(label::LazyNodeLabel) = materialize_lazy_node_label(label, nothing)

function materialize_lazy_node_label(label, index)
    check_data_compatibility(label, index)
    return __materialize_lazy_node_label(label, index)
end

function __materialize_lazy_node_label(label, index::Tuple)
    return getorcreate!(label.model, label.context, label.options, label.name, index...)[index...]
end

function __materialize_lazy_node_label(label, index::Nothing)
    return getorcreate!(label.model, label.context, label.options, label.name, nothing)
end

function check_data_compatibility(label, index)
    if !__check_data_compatibility(label, index)
        error(
            """
      The index `[$(!isnothing(index) ? join(index, ", ") : nothing)]` is not compatible with the underlying collection provided for the label `$(label.name)`.
      The underlying data provided for `$(label.name)` is `$(label.collection)`.
      """
        )
    end
    return nothing
end

function __check_data_compatibility(label::LazyNodeLabel, index::Nothing)
    # We assume that no index is always compatible with the underlying collection
    # Eg. a matrix `Σ` can be used both as it is `Σ`, but also as `Σ[1]` or `Σ[1, 1]`
    return true
end

function __check_data_compatibility(label::LazyNodeLabel, index::Tuple)
    return __check_data_compatibility(label, label.collection, index)
end

# We can't really check if the data compatible or not if we get the `MissingCollection`
__check_data_compatibility(label::LazyNodeLabel, ::MissingCollection, index::Tuple) = true
__check_data_compatibility(label::LazyNodeLabel, collection::AbstractArray, indices::Tuple) = checkbounds(Bool, collection, indices...)
__check_data_compatibility(label::LazyNodeLabel, collection::Tuple, indices::Tuple) =
    length(indices) === 1 && first(indices) ∈ 1:length(collection)
# A number cannot really be queried with non-empty indices
__check_data_compatibility(label::LazyNodeLabel, collection::Number, indices::Tuple) = false
# For all other we simply don't know so we assume we are compatible
__check_data_compatibility(label::LazyNodeLabel, collection, indices::Tuple) = true

__proxy_unroll(::ProxyLabel, index, proxied::LazyNodeLabel) = materialize_lazy_node_label(proxied, index)

"""
    add_variable_node!(model::Model, context::Context, options::NodeCreationOptions, name::Symbol, index)

Add a variable node to the model with the given `name` and `index`.
This function is unsafe (doesn't check if a variable with the given name already exists in the model). 

Args:
    - `model::Model`: The model to which the node is added.
    - `context::Context`: The context to which the symbol is added.
    - `options::NodeCreationOptions`: The options for the creation process.
    - `name::Symbol`: The ID of the variable.
    - `index::Union{Nothing, Int, NTuple{N, Int64} where N} = nothing`: The index of the variable.

Returns:
    - The generated symbol for the variable.
"""
function add_variable_node! end

function add_variable_node!(model::Model, context::Context, name::Symbol, index)
    return add_variable_node!(model, context, EmptyNodeCreationOptions, name, index)
end

function add_variable_node!(model::Model, context::Context, options::NodeCreationOptions, name::Symbol, index)

    # In theory plugins are able to overwrite this
    potential_label = generate_nodelabel(model, name)
    potential_nodedata = NodeData(context, convert(VariableNodeProperties, name, index, options))
    label, nodedata = preprocess_plugins(
        UnionPluginType(VariableNodePlugin(), FactorAndVariableNodesPlugin()), model, context, potential_label, potential_nodedata, options
    )

    context[name, index] = label
    model[label] = nodedata

    return label
end

"""
    AnonymousVariable(model, context)

Defines a lazy structure for anonymous variables.
The actual anonymous variables materialize only in `make_node!` upon calling, because it needs arguments to the `make_node!` in order to create proper links.
"""
struct AnonymousVariable
    model::Model
    context::Context
end

create_anonymous_variable!(model::Model, context::Context) = AnonymousVariable(model, context)

function materialize_anonymous_variable!(anonymous::AnonymousVariable, fform, args)
    return materialize_anonymous_variable!(NodeBehaviour(fform), anonymous.model, anonymous.context, args)
end

# Deterministic nodes can create links to variables in the model
# This might be important for better factorization constraints resolution
function materialize_anonymous_variable!(::Deterministic, model::Model, context::Context, args)
    return add_variable_node!(
        model, context, NodeCreationOptions(link = getindex.(Ref(model), unroll.(filter(is_nodelabel, args)))), :anonymous, nothing
    )
end

function materialize_anonymous_variable!(::Deterministic, model::Model, context::Context, args::NamedTuple)
    return materialize_anonymous_variable!(Deterministic(), model, context, values(args))
end

function materialize_anonymous_variable!(::Stochastic, model::Model, context::Context, _)
    return add_variable_node!(model, context, NodeCreationOptions(), :anonymous, nothing)
end

"""
    add_atomic_factor_node!(model::Model, context::Context, options::NodeCreationOptions, fform)

Add an atomic factor node to the model with the given name.
The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `FactorNodeData` struct.

Args:
    - `model::Model`: The model to which the node is added.
    - `context::Context`: The context to which the symbol is added.
    - `options::NodeCreationOptions`: The options for the creation process.
    - `fform::Any`: The functional form of the node.

Returns:
    - The generated label for the node.
"""
function add_atomic_factor_node! end

function add_atomic_factor_node!(model::Model, context::Context, options::NodeCreationOptions, fform::F) where {F}
    factornode_id = generate_factor_nodelabel(context, fform)

    potential_label = generate_nodelabel(model, fform)
    potential_nodedata = NodeData(context, convert(FactorNodeProperties, fform, options))

    label, nodedata = preprocess_plugins(
        UnionPluginType(FactorNodePlugin(), FactorAndVariableNodesPlugin()), model, context, potential_label, potential_nodedata, options
    )

    model[label] = nodedata
    context[factornode_id] = label

    return label, nodedata, convert(FactorNodeProperties, getproperties(nodedata))
end

factor_alias(any, interfaces) = any
factor_alias(::typeof(+), interfaces) = sum
factor_alias(::typeof(*), interfaces) = prod

"""
Add a composite factor node to the model with the given name.

The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `NodeData` struct with `is_variable` set to
`false` and `node_name` set to the given name.

Args:
    - `model::Model`: The model to which the node is added.
    - `parent_context::Context`: The context to which the symbol is added.
    - `context::Context`: The context of the composite factor node.
    - `node_name::Symbol`: The name of the node.

Returns:
    - The generated id for the node.
"""
function add_composite_factor_node!(model::Model, parent_context::Context, context::Context, node_name)
    node_id = generate_factor_nodelabel(parent_context, node_name)
    parent_context[node_id] = context
    return node_id
end

iterator(interfaces::NamedTuple) = zip(keys(interfaces), values(interfaces))

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    factor_node_propeties::FactorNodeProperties,
    variable_node_id::Union{ProxyLabel, NodeLabel},
    interface_name::Symbol
)
    return add_edge!(model, factor_node_id, factor_node_propeties, variable_node_id, interface_name, nothing)
end

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    factor_node_propeties::FactorNodeProperties,
    variable_node_id::Union{AbstractArray, Tuple, NamedTuple},
    interface_name::Symbol
)
    return add_edge!(model, factor_node_id, factor_node_propeties, variable_node_id, interface_name, 1)
end

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    factor_node_propeties::FactorNodeProperties,
    variable_node_id::Union{ProxyLabel, NodeLabel},
    interface_name::Symbol,
    index
)
    label = EdgeLabel(interface_name, index)
    neighbor_node_label = unroll(variable_node_id)
    # TODO: (bvdmitri) perhaps we should use a different data structure for neighbors, tuples extension might be slow
    addneighbor!(factor_node_propeties, neighbor_node_label, label, model[neighbor_node_label])
    model.graph[unroll(variable_node_id), factor_node_id] = label
end

function add_edge!(
    model::Model,
    factor_node_id::NodeLabel,
    factor_node_propeties::FactorNodeProperties,
    variable_nodes::Union{AbstractArray, Tuple, NamedTuple},
    interface_name::Symbol,
    index
)
    for variable_node in variable_nodes
        add_edge!(model, factor_node_id, factor_node_propeties, variable_node, interface_name, index)
        index += increase_index(variable_node)
    end
end

increase_index(any) = 1
increase_index(x::AbstractArray) = length(x)

struct MixedArguments{A <: Tuple, K <: NamedTuple}
    args::A
    kwargs::K
end

"""
Placeholder function that is defined for all Composite nodes and is invoked when inferring what interfaces are missing when a node is called
"""
interfaces(any_f, ::StaticInt{1}) = StaticInterfaces((:out,))
interfaces(any_f, any_val) = StaticInterfaces((:out, :in))

"""
    missing_interfaces(node_type, val, known_interfaces)

Returns the interfaces that are missing for a node. This is used when inferring the interfaces for a node that is composite.

# Arguments
- `node_type`: The type of the node as a Function object.
- `val`: The value of the amount of interfaces the node is supposed to have. This is a `Static.StaticInt` object.
- `known_interfaces`: The known interfaces for the node.

# Returns
- `missing_interfaces`: A `Vector` of the missing interfaces.
"""
function missing_interfaces(fform, val, known_interfaces::NamedTuple)
    return missing_interfaces(interfaces(fform, val), StaticInterfaces(keys(known_interfaces)))
end

function missing_interfaces(
    ::StaticInterfaces{all_interfaces}, ::StaticInterfaces{present_interfaces}
) where {all_interfaces, present_interfaces}
    return StaticInterfaces(filter(interface -> interface ∉ present_interfaces, all_interfaces))
end

function prepare_interfaces(fform, lhs_interface, rhs_interfaces::NamedTuple)
    missing_interface = missing_interfaces(fform, static(length(rhs_interfaces)) + static(1), rhs_interfaces)
    return prepare_interfaces(missing_interface, fform, lhs_interface, rhs_interfaces)
end

function prepare_interfaces(::StaticInterfaces{I}, fform, lhs_interface, rhs_interfaces::NamedTuple) where {I}
    @assert length(I) == 1 lazy"Expected only one missing interface, got $I of length $(length(I)) (node $fform with interfaces $(keys(rhs_interfaces)))))"
    missing_interface = first(I)
    return NamedTuple{(missing_interface, keys(rhs_interfaces)...)}((lhs_interface, values(rhs_interfaces)...))
end

materialize_interface(interface) = interface

function materialze_interfaces(interfaces::NamedTuple)
    return map(materialize_interface, interfaces)
end

default_parametrization(::Atomic, fform, rhs::Tuple) = (in = rhs,)
default_parametrization(::Composite, fform, rhs) = error("Composite nodes always have to be initialized with named arguments")

# maybe change name

is_nodelabel(x) = false
is_nodelabel(x::AbstractArray) = any(element -> is_nodelabel(element), x)
is_nodelabel(x::GraphPPL.NodeLabel) = true
is_nodelabel(x::ProxyLabel) = true

function contains_nodelabel(collection::Tuple)
    return any(element -> is_nodelabel(element), collection) ? True() : False()
end

function contains_nodelabel(collection::NamedTuple)
    return any(element -> is_nodelabel(element), values(collection)) ? True() : False()
end

function contains_nodelabel(collection::MixedArguments)
    return contains_nodelabel(collection.args) | contains_nodelabel(collection.kwargs)
end

# TODO improve documentation

function make_node!(model::Model, ctx::Context, fform::F, lhs_interfaces, rhs_interfaces) where {F}
    return make_node!(model, ctx, EmptyNodeCreationOptions, fform, lhs_interfaces, rhs_interfaces)
end

# Special case which should materialize anonymous variable
function make_node!(model::Model, ctx::Context, options::NodeCreationOptions, fform::F, lhs_interface::AnonymousVariable, rhs_interfaces) where {F}
    lhs_materialized = materialize_anonymous_variable!(lhs_interface, fform, rhs_interfaces)::NodeLabel
    return make_node!(model, ctx, options, fform, lhs_materialized, rhs_interfaces)
end

make_node!(model::Model, ctx::Context, options::NodeCreationOptions, fform::F, lhs_interface, rhs_interfaces)  where {F} =
    make_node!(NodeType(fform), model, ctx, options, fform, lhs_interface, rhs_interfaces)

#if it is composite, we assume it should be materialized and it is stochastic
make_node!(nodetype::Composite, model::Model, ctx::Context, options::NodeCreationOptions, fform::F, lhs_interface, rhs_interfaces)  where {F} =
    make_node!(True(), nodetype, Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If a node is an object and not a function, we materialize it as a stochastic atomic node
make_node!(model::Model, ctx::Context, options::NodeCreationOptions, fform::F, lhs_interface, rhs_interfaces::Nothing)  where {F} =
    make_node!(True(), Atomic(), Stochastic(), model, ctx, options, fform, lhs_interface, NamedTuple{}())

# If node is Atomic, check stochasticity
make_node!(::Atomic, model::Model, ctx::Context, options::NodeCreationOptions, fform::F, lhs_interface, rhs_interfaces)  where {F} =
    make_node!(Atomic(), NodeBehaviour(fform), model, ctx, options, fform, lhs_interface, rhs_interfaces)

#If a node is deterministic, we check if there are any NodeLabel objects in the rhs_interfaces (direct check if node should be materialized)
make_node!(
    atomic::Atomic,
    deterministic::Deterministic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces
) where {F} = make_node!(contains_nodelabel(rhs_interfaces), atomic, deterministic, model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If the node should not be materialized (if it's Atomic, Deterministic and contains no NodeLabel objects), we return the function evaluated at the interfaces
make_node!(
    ::False,
    ::Atomic,
    ::Deterministic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces::Tuple
) where {F} = (nothing, fform(rhs_interfaces...))

make_node!(
    ::False,
    ::Atomic,
    ::Deterministic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces::NamedTuple
)  where {F} = (nothing, fform(; rhs_interfaces...))

make_node!(
    ::False,
    ::Atomic,
    ::Deterministic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces::MixedArguments
) where {F} = (nothing, fform(rhs_interfaces.args...; rhs_interfaces.kwargs...))

# If a node is Stochastic, we always materialize.
make_node!(::Atomic, ::Stochastic, model::Model, ctx::Context, options::NodeCreationOptions, fform::F, lhs_interface, rhs_interfaces)  where {F} =
    make_node!(True(), Atomic(), Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If we have to materialize but lhs_interface is nothing, we create a variable for it
function make_node!(
    materialize::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Broadcasted,
    rhs_interfaces
) where {F}
    lhs_node = ProxyLabel(
        getname(lhs_interface), nothing, add_variable_node!(model, ctx, EmptyNodeCreationOptions, gensym(getname(lhs_interface)), nothing)
    )
    return make_node!(materialize, node_type, behaviour, model, ctx, options, fform, lhs_node, rhs_interfaces)
end

# If we have to materialize but the rhs_interfaces argument is not a NamedTuple, we convert it
make_node!(
    materialize::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::Tuple
) where {F} = make_node!(
    materialize,
    node_type,
    behaviour,
    model,
    ctx,
    options,
    fform,
    lhs_interface,
    GraphPPL.default_parametrization(node_type, fform, rhs_interfaces)
)

make_node!(
    ::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::MixedArguments
)  where {F} = error("MixedArguments not supported for rhs_interfaces when node has to be materialized")

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::Tuple{}
)  where {F} = make_node!(materialize, node_type, behaviour, model, ctx, options, fform, lhs_interface, NamedTuple{}())

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::Tuple
)  where {F} = error(lazy"Composite node $fform cannot should be called with explicitly naming the interface names")

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::NamedTuple
)  where {F} = make_node!(Composite(), model, ctx, options, fform, lhs_interface, rhs_interfaces, static(length(rhs_interfaces) + 1))

"""
    make_node!

Make a new factor node in the Model and specified Context, attach it to the specified interfaces, and return the interface that is on the lhs of the `~` operator.

# Arguments
- `model::Model`: The model to add the node to.
- `ctx::Context`: The context in which to add the node.
- `fform`: The function that the node represents.
- `lhs_interface`: The interface that is on the lhs of the `~` operator.
- `rhs_interfaces`: The interfaces that are the arguments of fform on the rhs of the `~` operator.
- `__parent_options__::NamedTuple = nothing`: The options to attach to the node.
- `__debug__::Bool = false`: Whether to attach debug information to the factor node.
"""
function make_node!(
    materialize::True,
    node_type::Atomic,
    behaviour::NodeBehaviour,
    model::Model,
    context::Context,
    options::NodeCreationOptions,
    fform::F,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::NamedTuple
)  where {F}
    fform = factor_alias(fform, Val(keys(rhs_interfaces)))
    interfaces = materialze_interfaces(prepare_interfaces(fform, lhs_interface, rhs_interfaces))
    nodeid, _, _ = materialize_factor_node!(model, context, options, fform, interfaces)
    return nodeid, unroll(lhs_interface)
end

sort_interfaces(fform, defined_interfaces::NamedTuple) =
    sort_interfaces(interfaces(fform, static(length(defined_interfaces))), defined_interfaces)

function sort_interfaces(::StaticInterfaces{I}, defined_interfaces::NamedTuple) where {I}
    return defined_interfaces[I]
end

function materialize_factor_node!(model::Model, context::Context, options::NodeCreationOptions, fform::F, interfaces::NamedTuple) where {F}
    interfaces = sort_interfaces(fform, interfaces)
    interfaces = map(interface -> getifcreated(model, context, unroll(interface)), interfaces)
    factor_node_id, factor_node_data, factor_node_properties = add_atomic_factor_node!(model, context, options, fform)
    for (interface_name, interface) in iterator(interfaces)
        add_edge!(model, factor_node_id, factor_node_properties, interface, interface_name)
    end
    return factor_node_id, factor_node_data, factor_node_properties
end

add_terminated_submodel!(model::Model, context::Context, fform, interfaces::NamedTuple) =
    add_terminated_submodel!(model, context, NodeCreationOptions((; created_by = () -> :($QuoteNode(fform)))), fform, interfaces)

add_terminated_submodel!(model::Model, context::Context, options::NodeCreationOptions, fform, interfaces::NamedTuple) =
    add_terminated_submodel!(model, context, options, fform, interfaces, static(length(interfaces)))

"""
Add the `fform` as the toplevel model to the `model` and `context` with the specified `interfaces`.
Calls the postprocess logic for the attached plugins of the model. Should be called only once for a given `Model` object.
"""
function add_toplevel_model! end

function add_toplevel_model!(model::Model, fform, interfaces)
    return add_toplevel_model!(model, getcontext(model), fform, interfaces)
end

function add_toplevel_model!(model::Model, context::Context, fform, interfaces)
    add_terminated_submodel!(model, context, fform, interfaces)
    foreach(getplugins(model)) do plugin
        postprocess_plugin(plugin, model)
    end
    return model
end

"""
    prune!(m::Model)

Remove all nodes from the model that are not connected to any other node.
"""
function prune!(m::Model)
    degrees = degree(m.graph)
    nodes_to_remove = keys(degrees)[degrees .== 0]
    nodes_to_remove = sort(nodes_to_remove, rev = true)
    rem_vertex!.(Ref(m.graph), nodes_to_remove)
end

## Plugin steps

"""
A trait object for plugins that add extra functionality for factor nodes.
"""
struct FactorNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for variable nodes.
"""
struct VariableNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality both for factor and variable nodes.
"""
struct FactorAndVariableNodesPlugin <: AbstractPluginTraitType end

"""
    preprocess_plugin(plugin, model, context, label, nodedata, options)

Call a plugin specific logic for a node with label and nodedata upon their creation.
"""
function preprocess_plugin end

"""
    postprocess(plugin, model)

Calls a plugin specific logic after the model has been created. By default does nothing.
"""
postprocess_plugin(plugin, model) = nothing

function preprocess_plugins(type::AbstractPluginTraitType, model::Model, context::Context, label, nodedata, options)
    plugins = filter(type, getplugins(model))
    return foldl(plugins; init = (label, nodedata)) do (label, nodedata), plugin
        return preprocess_plugin(plugin, model, context, label, nodedata, options)
    end
end
