using MetaGraphsNext, MetaGraphsNext.Graphs
using BitSetTuples
using Static
using NamedTupleTools

import Base: put!, haskey, gensym, getindex, getproperty, setproperty!, setindex!, vec, iterate
import MetaGraphsNext.Graphs: neighbors

aliases(f) = (f,)

struct Broadcasted
    name::Symbol
end

getname(broadcasted::Broadcasted) = broadcasted.name

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
- `plugin_specification`: A `PluginSpecification` object representing the plugins enabled in the model.
- `plugins`: A `PluginCollection` object representing the global plugins enabled in the model.
- `counter`: A `Base.RefValue{Int64}` object keeping track of the number of nodes in the graph.
"""
struct Model
    graph::MetaGraph
    plugin_specification::PluginSpecification
    plugins::PluginCollection
    counter::Base.RefValue{Int64}
end

labels(model::Model) = MetaGraphsNext.labels(model.graph)

getplugins_specification(model::Model) = model.plugin_specification

getplugins(model::Model) = model.plugins
getplugin(model::Model, ::Type{T}, throw_if_not_present = Val(true)) where {T} = getplugin(getplugins(model), T, throw_if_not_present)

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
unroll(label) = label
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

function withoutopts(options::NodeCreationOptions, ::Val{K}) where { K }
    newoptions = options.options[ filter(key -> key ∉ K, keys(options.options)) ]
    # Should be compiled out, there are tests for it
    if isempty(newoptions)
        return NodeCreationOptions(nothing)
    else
        return NodeCreationOptions(newoptions)
    end
end

# TODO: (bvdmitri) move mutable fields to the plugins and make the struct immutable
mutable struct VariableNodeProperties
    name::Symbol
    index::Any
    link::Any
    value::Any
    functional_form::Any
    message_constraint::Any
    constant::Bool
    datavar::Bool
    factorized::Bool
    meta::Any
    others::Any
end

VariableNodeProperties(;
    name,
    index,
    link = nothing,
    value = nothing,
    functional_form = nothing,
    message_constraint = nothing,
    constant = false,
    datavar = false,
    factorized = false,
    meta = nothing,
    others = nothing
) = VariableNodeProperties(name, index, link, value, functional_form, message_constraint, constant, datavar, factorized, meta, others)

is_factor(::VariableNodeProperties)   = false
is_variable(::VariableNodeProperties) = true

# TODO: (bvdmitri) maybe there is a better way (?)
function Base.convert(::Type{VariableNodeProperties}, name::Symbol, index, options::NodeCreationOptions)
    return VariableNodeProperties(
        name = name,
        index = index,
        link = get(options, :link, nothing),
        value = get(options, :value, nothing),
        functional_form = get(options, :functional_form, nothing),
        message_constraint = get(options, :message_constraint, nothing),
        constant = get(options, :constant, false),
        datavar = get(options, :datavar, false),
        factorized = get(options, :factorized, false),
        meta = get(options, :meta, nothing),
        others = get(options, :others, nothing),
    )
end

getname(properties::VariableNodeProperties) = properties.name
getlink(properties::VariableNodeProperties) = properties.link
index(properties::VariableNodeProperties) = properties.index
value(properties::VariableNodeProperties) = properties.value
is_factorized(properties::VariableNodeProperties) = (properties.factorized || is_constant(properties)) || (!isnothing(getlink(properties)) && all(is_factorized, getlink(properties)))
is_datavar(properties::VariableNodeProperties) = properties.datavar
is_constant(properties::VariableNodeProperties) = properties.constant
fform_constraint(properties::VariableNodeProperties) = properties.functional_form
message_constraint(properties::VariableNodeProperties) = properties.message_constraint
meta(properties::VariableNodeProperties) = properties.meta

function Base.show(io::IO, properties::VariableNodeProperties)
    print(io, "name = ", properties.name, ", index = ", properties.index)
    if !isnothing(node.link)
        print(io, "(linked to ", node.link, ")")
    end
end

"""
    FactorNodeProperties(fform::Any, factorization_constraint::Any, neighbours::Any)

Data associated with a factor node in a probabilistic graphical model.
"""
mutable struct FactorNodeProperties
    fform::Any
    neighbors::Any
    factorization_constraint::Any
end

FactorNodeProperties(;
    fform,
    neighbors = (),
    factorization_constraint = nothing,
) = FactorNodeProperties(fform, neighbors, factorization_constraint)

is_factor(::FactorNodeProperties)   = true
is_variable(::FactorNodeProperties) = false

function Base.convert(::Type{FactorNodeProperties}, fform, options::NodeCreationOptions)
    return FactorNodeProperties(
        fform = fform,
        neighbors = get(options, :neighbors, ()),
        factorization_constraint = get(options, :factorization_constraint, nothing),
    )
end

fform(properties::FactorNodeProperties) = properties.fform
factorization_constraint(properties::FactorNodeProperties) = properties.factorization_constraint
neighbors(properties::FactorNodeProperties) = properties.neighbors

set_factorization_constraint!(properties::FactorNodeProperties, constraint) = properties.factorization_constraint = constraint

"""
    NodeData(context, properties, plugins)

Data associated with a node in a probabilistic graphical model. 
The `context` field stores the context of the node. 
The `properties` field stores the properties of the node. 
The `plugins` field stores additional properties of the node depending on which plugins were enabled.
"""
struct NodeData{P}
    context    :: Any
    properties :: P
    plugins    :: PluginCollection
end

NodeData(context, properties) = NodeData(context, properties, PluginCollection())

function Base.show(io::IO, nodedata::NodeData)
    print(io, properties.name, "[", properties.index, "] in context ", node.context.prefix, "_", node.context.fform)
    print(io, "NodeData with properties: ")
    print(io, nodedata.properties)
    print(io, " in context ", nodedata.context.prefix, "_", node.context.fform)
    if !isempty(nodedata.plugins)
        print(io, " with plugins: ")
        print(io, nodedata.plugins)
    end
end

getcontext(node::NodeData)    = node.context
getproperties(node::NodeData) = node.properties

getplugins(node::NodeData) = node.plugins
getplugin(node::NodeData, ::Type{T}, throw_if_not_present = Val(true)) where {T} = getplugin(getplugins(node), T, throw_if_not_present)

is_factor(node::NodeData)   = is_factor(getproperties(node))
is_variable(node::NodeData) = is_variable(getproperties(node))

factor_nodes(model::Model)   = Iterators.filter(node -> is_factor(model[node]), labels(model))
variable_nodes(model::Model) = Iterators.filter(node -> is_variable(model[node]), labels(model))

"""
A structure that holds interfaces of a node in the type argument `I`. Used for dispatch.
"""
struct StaticInterfaces{I} end

StaticInterfaces(I::Tuple) = StaticInterfaces{I}()
Base.getindex(::StaticInterfaces{I}, index) where {I} = I[index]

struct ProxyLabel{T}
    name::Symbol
    index::T
    proxied::Any
end

proxylabel(name::Symbol, index::T, proxied::Union{NodeLabel, ProxyLabel, ResizableArray{NodeLabel}}) where {T} = ProxyLabel(name, index, proxied)
proxylabel(name::Symbol, index::T, proxied) where {T} = proxied

getname(label::ProxyLabel) = label.name
index(label::ProxyLabel) = label.index

unroll(proxy::ProxyLabel) = __proxy_unroll(proxy)

__proxy_unroll(something) = something
__proxy_unroll(proxy::ProxyLabel) = __proxy_unroll(proxy.index, proxy)
__proxy_unroll(::Nothing, proxy::ProxyLabel) = __proxy_unroll(proxy.proxied)
__proxy_unroll(index, proxy::ProxyLabel) = __proxy_unroll(proxy.proxied)[index...]
__proxy_unroll(index::FunctionalIndex, proxy::ProxyLabel) = __proxy_unroll(proxy.proxied)[index]

Base.show(io::IO, proxy::ProxyLabel{NTuple{N, Int}} where {N}) = print(io, getname(proxy), "[", index(proxy), "]")
Base.show(io::IO, proxy::ProxyLabel{Nothing}) = print(io, getname(proxy))
Base.show(io::IO, proxy::ProxyLabel) = print(io, getname(proxy), "[", index(proxy)[1], "]")
Base.getindex(proxy::ProxyLabel, indices...) = getindex(unroll(proxy), indices...)

Base.last(label::ProxyLabel) = last(label.proxied, label)

Base.last(proxied::ProxyLabel, ::ProxyLabel) = last(proxied)
Base.last(proxied, ::ProxyLabel) = proxied

Model(graph::MetaGraph) = Model(graph, PluginSpecification())

function Model(graph::MetaGraph, plugin_specification::PluginSpecification)
    plugins = materialize_plugins(GraphGlobalPlugin(), plugin_specification)
    return Model(graph, plugin_specification, plugins, Base.RefValue(0))
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
Graphs.edges(model::Model, nodes::AbstractArray{<:NodeLabel}) = Tuple(Iterators.flatten(map(node -> Graphs.edges(model, node), nodes)))

Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData) = Graphs.edges(model, node, nodedata, getproperties(nodedata))
Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties) = map(neighbor -> neighbor[2], neighbors(properties))

function Graphs.edges(model::Model, node::NodeLabel, nodedata::NodeData, properties::VariableNodeProperties)
    return Tuple(model[node, dst] for dst in MetaGraphsNext.neighbor_labels(model.graph, node))
end

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
    Context

Contains all information about a submodel in a probabilistic graphical model.
"""
struct Context
    depth::Int64
    fform::Function
    prefix::String
    parent::Union{Context, Nothing}
    children::Dict{FactorID, Context}
    individual_variables::Dict{Symbol, NodeLabel}
    vector_variables::Dict{Symbol, ResizableArray{NodeLabel}}
    tensor_variables::Dict{Symbol, ResizableArray}
    factor_nodes::Dict{FactorID, NodeLabel}
    proxies::Dict{Symbol, ProxyLabel}
    submodel_counts::Dict{Any, Int}
end

fform(context::Context) = context.fform
parent(context::Context) = context.parent
individual_variables(context::Context) = context.individual_variables
vector_variables(context::Context) = context.vector_variables
tensor_variables(context::Context) = context.tensor_variables
factor_nodes(context::Context) = context.factor_nodes
proxies(context::Context) = context.proxies
children(context::Context) = context.children
count(context::Context, fform::Any) = haskey(context.submodel_counts, fform) ? context.submodel_counts[fform] : 0

path_to_root(::Nothing) = []
path_to_root(context::Context) = [context, path_to_root(parent(context))...]

function generate_factor_nodelabel(context::Context, fform::Any)
    if count(context, fform) == 0
        context.submodel_counts[fform] = 1
    else
        context.submodel_counts[fform] += 1
    end
    return FactorID(fform, count(context, fform))
end

function Base.show(io::IO, context::Context)
    indentation = 2 * context.depth
    println(io, "$("    " ^ indentation)Context: $(context.prefix)")
    println(io, "$("    " ^ (indentation + 1))Individual variables:")
    for (variable_name, variable_label) in context.individual_variables
        println(io, "$("    " ^ (indentation + 2))$(variable_name): $(variable_label)")
    end
    println(io, "$("    " ^ (indentation + 1))Vector variables:")
    for (variable_name, variable_labels) in context.vector_variables
        println(io, "$("    " ^ (indentation + 2))$(variable_name)")
    end
    println(io, "$("    " ^ (indentation + 1))Tensor variables: ")
    for (variable_name, variable_labels) in context.tensor_variables
        println(io, "$("    " ^ (indentation + 2))$(variable_name)")
    end
    println(io, "$("    " ^ (indentation + 1))Factor nodes: ")
    for (factor_label, factor_context) in context.factor_nodes
        if isa(factor_context, Context)
            println(io, "$("    " ^ (indentation + 2))$(factor_label) : ")
            show(io, factor_context)
        else
            println(io, "$("    " ^ (indentation + 2))$(factor_label) : $(factor_context)")
        end
    end
    println(io, "$("    " ^ (indentation + 1))Child Contexts: ")
    for (child_name, child_context) in context.children
        println(io, "$("    " ^ (indentation + 2))$(child_name) : ")
        show(io, child_context)
    end
    println(io, "$("    " ^ (indentation + 1))Proxies from parent: ")
    for (proxy_name, proxy_label) in context.proxies
        println(io, "$("    " ^ (indentation + 2))$(proxy_name) : $(proxy_label)")
    end
end

getname(f::Function) = String(Symbol(f))

Context(depth::Int, fform::Function, prefix::String, parent) = Context(depth, fform, prefix, parent, Dict(), Dict(), Dict(), Dict(), Dict(), Dict(), Dict())

Context(parent::Context, model_fform::Function) = Context(parent.depth + 1, model_fform, (parent.prefix == "" ? parent.prefix : parent.prefix * "_") * getname(model_fform), parent)
Context(fform) = Context(0, fform, "", nothing)
Context() = Context(identity)

haskey(context::Context, key::Symbol) =
    haskey(context.individual_variables, key) || haskey(context.vector_variables, key) || haskey(context.tensor_variables, key) || haskey(context.proxies, key)

haskey(context::Context, key::FactorID) = haskey(context.factor_nodes, key) || haskey(context.children, key)

function Base.getindex(c::Context, key::Any)
    if haskey(c.individual_variables, key)
        return c.individual_variables[key]
    elseif haskey(c.vector_variables, key)
        return c.vector_variables[key]
    elseif haskey(c.tensor_variables, key)
        return c.tensor_variables[key]
    elseif haskey(c.factor_nodes, key)
        return c.factor_nodes[key]
    elseif haskey(c.children, key)
        return c.children[key]
    elseif haskey(c.proxies, key)
        return c.proxies[key]
    end
    throw(KeyError(key))
end

function Base.getindex(c::Context, fform, index::Int)
    return c[FactorID(fform, index)]
end

function Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::Nothing)
    return c.individual_variables[key] = val
end

function Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::Int)
    return c.vector_variables[key][index] = val
end

function Base.setindex!(c::Context, val::NodeLabel, key::Symbol, index::NTuple{N, Int64}) where {N}
    return c.tensor_variables[key][index...] = val
end

Base.setindex!(c::Context, val::ResizableArray{NodeLabel, T, 1} where {T}, key::Symbol) = c.vector_variables[key] = val

Base.setindex!(c::Context, val::ResizableArray{NodeLabel, T, N} where {T, N}, key::Symbol) = c.tensor_variables[key] = val

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

Base.getindex(context::Context, index::IndexedVariable{Nothing}) = context[index.variable]
Base.getindex(context::Context, index::IndexedVariable) = context[index.variable][index.index]

abstract type NodeType end

struct Composite <: NodeType end
struct Atomic <: NodeType end

NodeType(::Type) = Atomic()
NodeType(::Function) = Atomic()

abstract type NodeBehaviour end

struct Stochastic <: NodeBehaviour end
struct Deterministic <: NodeBehaviour end

NodeBehaviour(x) = Deterministic()

"""
create_model()

Create a new empty probabilistic graphical model. 

Returns:
A `Model` object representing the probabilistic graphical model.
"""
function create_model(; fform = identity, plugins = PluginSpecification())
    graph = MetaGraph(Graph(), label_type = NodeLabel, vertex_data_type = NodeData, graph_data = Context(fform), edge_data_type = EdgeLabel)
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

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::NodeLabel) = child_context.individual_variables[name_in_child] = object_in_parent

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ResizableArray{NodeLabel, V, 1}) where {V} =
    child_context.vector_variables[name_in_child] = object_in_parent

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ResizableArray{NodeLabel, V, N}) where {V, N} =
    child_context.tensor_variables[name_in_child] = object_in_parent

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ProxyLabel) = child_context.proxies[name_in_child] = object_in_parent

add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent) = nothing

throw_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ? error("Variable $name is already an individual variable in the model") : nothing
throw_if_vector_variable(context::Context, name::Symbol) = haskey(context.vector_variables, name) ? error("Variable $name is already a vector variable in the model") : nothing
throw_if_tensor_variable(context::Context, name::Symbol) = haskey(context.tensor_variables, name) ? error("Variable $name is already a tensor variable in the model") : nothing

""" 
    check_variate_compatability(node, index)

Will check if the index is compatible with the node object that is passed.

"""
check_variate_compatability(node::NodeLabel, index::Nothing) = true
check_variate_compatability(node::NodeLabel, index) = error("Cannot call single random variable on the left-hand-side by an indexed statement")

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

function getorcreate!(model::Model, ctx::Context, name::Symbol, index...)
    return getorcreate!(model, ctx, EmptyNodeCreationOptions, name, index...)
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index::Nothing)
    throw_if_vector_variable(ctx, name)
    throw_if_tensor_variable(ctx, name)
    return get(() -> add_variable_node!(model, ctx, options, name, index), ctx.individual_variables, name)
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index::AbstractArray{Int}) 
    return getorcreate!(model, ctx, options, name, index...)
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index::Integer)
    throw_if_individual_variable(ctx, name)
    throw_if_tensor_variable(ctx, name)
    if !haskey(ctx.vector_variables, name)
        ctx.vector_variables[name] = ResizableArray(NodeLabel, Val(1))
    end
    if !isassigned(ctx.vector_variables[name], index)
        ctx.vector_variables[name][index] = add_variable_node!(model, ctx, options, name, index)
    end
    return ctx.vector_variables[name]
end

function getorcreate!(model::Model, ctx::Context, options::NodeCreationOptions, name::Symbol, index...)
    throw_if_individual_variable(ctx, name)
    throw_if_vector_variable(ctx, name)
    if !haskey(ctx.tensor_variables, name)
        ctx.tensor_variables[name] = ResizableArray(NodeLabel, Val(length(index)))
    end
    if !isassigned(ctx.tensor_variables[name], index...)
        ctx.tensor_variables[name][index...] = add_variable_node!(model, ctx, options, name, index)
    end
    return ctx.tensor_variables[name]
end

getifcreated(model::Model, context::Context, var::NodeLabel) = var
getifcreated(model::Model, context::Context, var::ResizableArray) = var
getifcreated(model::Model, context::Context, var::Union{Tuple, AbstractArray{NodeLabel}}) = map((v) -> getifcreated(model, context, v), var)
getifcreated(model::Model, context::Context, var::ProxyLabel) = var

getifcreated(model::Model, context::Context, var) = add_variable_node!(model, context, NodeCreationOptions(value = var, constant = true), gensym(model, :constvar), nothing)

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
    variable_symbol = generate_nodelabel(model, name)

    properties = convert(VariableNodeProperties, name, index, options)
    plugins = materialize_plugins(VariableNodePlugin(), getplugins_specification(model))
    nodedata = NodeData(context, properties, plugins)
    
    context[name, index] = variable_symbol
    model[variable_symbol] = nodedata

    return variable_symbol
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
    return add_variable_node!(model, context, NodeCreationOptions(link = getindex.(Ref(model), unroll.(filter(is_nodelabel, args)))), :anonymous, nothing)
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

function add_atomic_factor_node!(model::Model, context::Context, fform)
    return add_atomic_factor_node!(model, context, EmptyNodeCreationOptions, fform)
end

function add_atomic_factor_node!(model::Model, context::Context, options::NodeCreationOptions, fform)
    factornode_id = generate_factor_nodelabel(context, fform)
    factornode_label = generate_nodelabel(model, fform)

    properties = convert(FactorNodeProperties, fform, options)
    plugins = materialize_plugins(FactorNodePlugin(), getplugins_specification(model))
    nodedata = NodeData(context, properties, plugins)

    modify_plugin!(plugins, NodeCreatedByPlugin, Val(false)) do plugin
        # bvdmitri: TODO
        plugin.created_by = options.options[:created_by]
    end

    model[factornode_label] = nodedata
    context.factor_nodes[factornode_id] = factornode_label
    
    return factornode_label
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
    parent_context.children[node_id] = context
    return node_id
end

iterator(interfaces::NamedTuple) = zip(keys(interfaces), values(interfaces))

function add_edge!(model::Model, factor_node_id::NodeLabel, variable_node_id::Union{ProxyLabel, NodeLabel}, interface_name::Symbol; index = nothing)
    label = EdgeLabel(interface_name, index)
    nodedata = model[factor_node_id]
    properties = getproperties(nodedata)
    # TODO: (bvdmitri) perhaps we should use a different data structure for neighbors, tuples extension might be slow
    properties.neighbors = (properties.neighbors..., (unroll(variable_node_id), label))
    model.graph[unroll(variable_node_id), factor_node_id] = label
end

function add_edge!(model::Model, factor_node_id::NodeLabel, variable_nodes::Union{AbstractArray, Tuple, NamedTuple}, interface_name::Symbol; index = 1)
    for variable_node in variable_nodes
        add_edge!(model, factor_node_id, variable_node, interface_name; index = index)
        index += increase_index(variable_node)
    end
end
increase_index(any) = 1
increase_index(x::AbstractArray) = length(x)

function add_factorization_constraint!(model::Model, factor_node_id::NodeLabel)
    return add_factorization_constraint!(model, factor_node_id, model[factor_node_id])
end

function add_factorization_constraint!(model::Model, factor_node_id::NodeLabel, nodedata::NodeData)
    return add_factorization_constraint!(model, factor_node_id, nodedata, getproperties(nodedata))
end

function add_factorization_constraint!(model::Model, factor_node_id::NodeLabel, nodedata::NodeData, properties::FactorNodeProperties)
    out_degree = length(neighbors(properties))
    constraint = BitSetTuple(out_degree)
    set_factorization_constraint!(properties, constraint)
    return nothing
end

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

function missing_interfaces(::StaticInterfaces{all_interfaces}, ::StaticInterfaces{present_interfaces}) where {all_interfaces, present_interfaces}
    return StaticInterfaces(filter(interface -> interface ∉ present_interfaces, all_interfaces))
end

function prepare_interfaces(fform, lhs_interface, rhs_interfaces::NamedTuple)
    missing_interface = missing_interfaces(fform, static(length(rhs_interfaces)) + static(1), rhs_interfaces)
    return prepare_interfaces(missing_interface, lhs_interface, rhs_interfaces)
end

function prepare_interfaces(::StaticInterfaces{I}, lhs_interface, rhs_interfaces::NamedTuple) where {I}
    @assert length(I) == 1 lazy"Expected only one missing interface, got $I of length $(length(I)) (node $fform with interfaces $(keys(rhs_interfaces)))))"
    missing_interface = first(I)
    return NamedTuple{(missing_interface, keys(rhs_interfaces)...)}((lhs_interface, values(rhs_interfaces)...))
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

function make_node!(model::Model, ctx::Context, fform, lhs_interfaces, rhs_interfaces)
    return make_node!(model, ctx, EmptyNodeCreationOptions, fform, lhs_interfaces, rhs_interfaces)
end

# Special case which should materialize anonymous variable
function make_node!(model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface::AnonymousVariable, rhs_interfaces)
    lhs_materialized = materialize_anonymous_variable!(lhs_interface, fform, rhs_interfaces)
    return make_node!(model, ctx, options, fform, lhs_materialized, rhs_interfaces)
end

make_node!(model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces) =
    make_node!(NodeType(fform), model, ctx, options, fform, lhs_interface, rhs_interfaces)

#if it is composite, we assume it should be materialized and it is stochastic
make_node!(nodetype::Composite, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces) =
    make_node!(True(), nodetype, Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If a node is an object and not a function, we materialize it as a stochastic atomic node
make_node!(model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces::Nothing) =
    make_node!(True(), Atomic(), Stochastic(), model, ctx, options, fform, lhs_interface, NamedTuple{}())

# If node is Atomic, check stochasticity
make_node!(::Atomic, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces) =
    make_node!(Atomic(), NodeBehaviour(fform), model, ctx, options, fform, lhs_interface, rhs_interfaces)

#If a node is deterministic, we check if there are any NodeLabel objects in the rhs_interfaces (direct check if node should be materialized)
make_node!(atomic::Atomic, deterministic::Deterministic, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces) =
    make_node!(contains_nodelabel(rhs_interfaces), atomic, deterministic, model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If the node should not be materialized (if it's Atomic, Deterministic and contains no NodeLabel objects), we return the function evaluated at the interfaces
make_node!(::False, ::Atomic, ::Deterministic, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces::Tuple) =
    fform(rhs_interfaces...)

make_node!(::False, ::Atomic, ::Deterministic, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces::NamedTuple) =
    fform(; rhs_interfaces...)

make_node!(::False, ::Atomic, ::Deterministic, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces::MixedArguments) =
    fform(rhs_interfaces.args...; rhs_interfaces.kwargs...)

# If a node is Stochastic, we always materialize.
make_node!(::Atomic, ::Stochastic, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface, rhs_interfaces) =
    make_node!(True(), Atomic(), Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If we have to materialize but lhs_interface is nothing, we create a variable for it
function make_node!(
    materialize::True, node_type::NodeType, behaviour::NodeBehaviour, model::Model, ctx::Context, options::NodeCreationOptions, fform, lhs_interface::Broadcasted, rhs_interfaces
)
    lhs_node = ProxyLabel(getname(lhs_interface), nothing, add_variable_node!(model, ctx, EmptyNodeCreationOptions, gensym(getname(lhs_interface)), nothing))
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
    fform,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::Tuple
) = make_node!(materialize, node_type, behaviour, model, ctx, options, fform, lhs_interface, GraphPPL.default_parametrization(node_type, fform, rhs_interfaces))

make_node!(
    ::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::MixedArguments
) = error("MixedArguments not supported for rhs_interfaces when node has to be materialized")

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::Tuple{}
) = make_node!(materialize, node_type, behaviour, model, ctx, options, fform, lhs_interface, NamedTuple{}())

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::Tuple
) = error(lazy"Composite node $fform cannot should be called with explicitly naming the interface names")

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::Model,
    ctx::Context,
    options::NodeCreationOptions,
    fform,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::NamedTuple
) = make_node!(Composite(), model, ctx, options, fform, lhs_interface, rhs_interfaces, static(length(rhs_interfaces) + 1))

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
    fform,
    lhs_interface::Union{NodeLabel, ProxyLabel},
    rhs_interfaces::NamedTuple
)
    fform = factor_alias(fform, Val(keys(rhs_interfaces)))
    interfaces = prepare_interfaces(fform, lhs_interface, rhs_interfaces)
    materialize_factor_node!(model, context, options, fform, interfaces)
    return unroll(lhs_interface)
end

sort_interfaces(fform, defined_interfaces::NamedTuple) = sort_interfaces(interfaces(fform, static(length(defined_interfaces))), defined_interfaces)

function sort_interfaces(::StaticInterfaces{I}, defined_interfaces::NamedTuple) where {I}
    return defined_interfaces[I]
end

function materialize_factor_node!(model::Model, context::Context, options::NodeCreationOptions, fform, interfaces::NamedTuple)
    interfaces = sort_interfaces(fform, interfaces)
    factor_node_id = add_atomic_factor_node!(model, context, options, fform)
    for (interface_name, neighbor_nodelabel) in iterator(interfaces)
        add_edge!(model, factor_node_id, GraphPPL.getifcreated(model, context, neighbor_nodelabel), interface_name)
    end
    # TODO (bvdmitri): this must be a part of the addons, perhaps move to the `add_atomic_factor_node!`
    add_factorization_constraint!(model, factor_node_id)
end

add_terminated_submodel!(model::Model, context::Context, fform, interfaces::NamedTuple) =
    add_terminated_submodel!(model, context, NodeCreationOptions((; created_by = :($QuoteNode(fform)))), fform, interfaces)

add_terminated_submodel!(model::Model, context::Context, options::NodeCreationOptions, fform, interfaces::NamedTuple) =
    add_terminated_submodel!(model, context, options, fform, interfaces, static(length(interfaces)))

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
