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
    returnval::Ref{Any}
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
        UnorderedDictionary{Symbol, ProxyLabel}(),
        Ref{Any}()
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

returnval(context::Context) = context.returnval[]

function returnval!(context::Context, value)
    context.returnval[] = postprocess_returnval(value)
end

# We do not want to return `VariableRef` from the model
# In this case we replace them with the actual node labels
postprocess_returnval(value) = value
postprocess_returnval(value::Tuple) = map(postprocess_returnval, value)

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

function copy_markov_blanket_to_child_context(child_context::Context, interfaces::NamedTuple)
    foreach(pairs(interfaces)) do (name_in_child, object_in_parent)
        add_to_child_context(child_context, name_in_child, object_in_parent)
    end
end

function add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent::ProxyLabel)
    set!(child_context.proxies, name_in_child, object_in_parent)
    return nothing
end

function add_to_child_context(child_context::Context, name_in_child::Symbol, object_in_parent)
    # By default, we assume that `object_in_parent` is a constant, so there is no need to save it in the context
    return nothing
end

throw_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ? error("Variable $name is already an individual variable in the model") : nothing
throw_if_vector_variable(context::Context, name::Symbol) =
    haskey(context.vector_variables, name) ? error("Variable $name is already a vector variable in the model") : nothing
throw_if_tensor_variable(context::Context, name::Symbol) =
    haskey(context.tensor_variables, name) ? error("Variable $name is already a tensor variable in the model") : nothing