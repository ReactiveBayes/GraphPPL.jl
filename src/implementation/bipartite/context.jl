
"""
    Context <: ContextInterface

Contains all information about a submodel in a probabilistic graphical model.
Implements the [`ContextInterface`](@ref).
"""
struct Context <: ContextInterface
    depth::Int64
    fform::Function
    prefix::String
    parent::Union{Context, Nothing}
    submodel_counts::UnorderedDictionary{Function, Int}
    children::UnorderedDictionary{Function, Vector{Context}}
    factor_nodes::UnorderedDictionary{Any, Vector{FactorNodeLabel}}
    individual_variables::UnorderedDictionary{Symbol, VariableNodeLabel}
    vector_variables::UnorderedDictionary{Symbol, ResizableArray{VariableNodeLabel, Vector{VariableNodeLabel}, 1}}
    tensor_variables::UnorderedDictionary{Symbol, ResizableArray{VariableNodeLabel}}
    proxies::UnorderedDictionary{Symbol, ProxyLabel}
    returnval::Ref{Any}

    function Context(depth::Int, fform::Function, prefix::String, parent::Union{Context, Nothing})
        return new(
            depth,
            fform,
            prefix,
            parent,
            UnorderedDictionary{Function, Int}(),
            UnorderedDictionary{Function, Vector{Context}}(),
            UnorderedDictionary{Any, Vector{FactorNodeLabel}}(),
            UnorderedDictionary{Symbol, VariableNodeLabel}(),
            UnorderedDictionary{Symbol, ResizableArray{VariableNodeLabel, Vector{VariableNodeLabel}, 1}}(),
            UnorderedDictionary{Symbol, ResizableArray{VariableNodeLabel}}(),
            UnorderedDictionary{Symbol, ProxyLabel}(),
            Ref{Any}(nothing)
        )
    end
end

# We need to implement the `create_root_context` method for the `ContextInterface` interface
function create_root_context(::Type{Context})
    return Context(0, identity, "", nothing)
end

function create_child_context(parent::Context, fform::F, markov_blanket::NamedTuple) where {F}
    child = Context(parent.depth + 1, fform, string(parent.prefix, "_", fform), parent)
    foreach(pairs(markov_blanket)) do (name_in_child, object_in_parent)
        # All other types of objects are assumed to be constants, 
        # so we don't need to save them in the context
        if object_in_parent isa ProxyLabel
            set!(child.proxies, name_in_child, object_in_parent)
        end
    end
    return child
end

get_depth(context::Context) = context.depth
get_functional_form(context::Context) = context.fform
get_prefix(context::Context) = context.prefix
get_parent(context::Context) = context.parent
get_short_name(context::Context) = string(context.prefix)

get_returnval(context::Context) = context.returnval[]
set_returnval!(context::Context, value) = context.returnval[] = postprocess_returnval(context, value)

function get_path_to_root(context::Context)
    path = [context]
    while get_parent(context) !== nothing
        push!(path, get_parent(context))
        context = get_parent(context)
    end
    return path
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

function get_variable(c::Context, key::Symbol)
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

function get_variable(c::Context, key::Symbol, index::Nothing)
    return get_variable(c, key)
end

function get_variable(c::Context, key::Symbol, index)
    return c.vector_variables[key][index]
end

function get_variable(c::Context, key::Symbol, index, indices...)
    return c.tensor_variables[key][index, indices...]
end

function has_variable(context::Context, key::Symbol)
    return haskey(context.individual_variables, key) ||
           haskey(context.vector_variables, key) ||
           haskey(context.tensor_variables, key) ||
           haskey(context.proxies, key)
end

function has_variable(c::Context, key::Symbol, index::Nothing)
    return has_variable(c, key)
end

function has_variable(c::Context, key::Symbol, index)
    return haskey(c.vector_variables, key) && isassigned(c.vector_variables[key], index)
end

function has_variable(c::Context, key::Symbol, index, indices...)
    return haskey(c.tensor_variables, key) && isassigned(c.tensor_variables[key], index, indices...)
end

set_variable!(c::Context, val::VariableNodeLabel, key::Symbol) = set!(c.individual_variables, key, val)
set_variable!(c::Context, val::VariableNodeLabel, key::Symbol, index::Nothing) = set!(c.individual_variables, key, val)
set_variable!(c::Context, val::VariableNodeLabel, key::Symbol, index::Int) = c.vector_variables[key][index] = val
set_variable!(c::Context, val::VariableNodeLabel, key::Symbol, index::NTuple{N, Int64} where {N}) = c.tensor_variables[key][index...] = val
set_variable!(c::Context, val::ResizableArray{VariableNodeLabel, T, 1} where {T}, key::Symbol) = set!(c.vector_variables, key, val)
set_variable!(c::Context, val::ResizableArray{VariableNodeLabel}, key::Symbol) = set!(c.tensor_variables, key, val)

set_variable!(c::Context, val::ProxyLabel, key::Symbol) = set!(c.proxies, key, val)
set_variable!(c::Context, val::ProxyLabel, key::Symbol, index::Nothing) = set!(c.proxies, key, val)
set_variable!(c::Context, val::ProxyLabel, key::Symbol, index) = error("Proxy labels cannot be set at an index")
set_variable!(c::Context, val::ProxyLabel, key::Symbol, index, indices...) = error("Proxy labels cannot be set at an index")

function has_factor(context::Context, functional_form)
    return haskey(context.factor_nodes, functional_form) || haskey(context.children, functional_form)
end

function has_factor(context::Context, functional_form, index)
    return (haskey(context.factor_nodes, functional_form) && isassigned(context.factor_nodes[functional_form], index)) ||
           (haskey(context.children, functional_form) && isassigned(context.children[functional_form], index))
end

function get_factor(c::Context, functional_form)
    return c.factor_nodes[functional_form]
end

function get_factor(c::Context, functional_form, index)
    return c.factor_nodes[functional_form][index]
end

function set_factor!(c::Context, val::Context, functional_form::F) where {F}
    if haskey(c.children, functional_form)
        push!(c.children[functional_form], val)
        return length(c.children[functional_form])
    else
        c.children[functional_form] = [val]
        return 1
    end
end

function set_factor!(c::Context, factor::FactorNodeLabel, functional_form::F) where {F}
    if haskey(c.factor_nodes, functional_form)
        push!(c.factor_nodes[functional_form], factor)
        return length(c.factor_nodes[functional_form])
    else
        c.factor_nodes[functional_form] = [factor]
        return 1
    end
end

throw_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ? error("Variable $name is already an individual variable in the model") : nothing
throw_if_vector_variable(context::Context, name::Symbol) =
    haskey(context.vector_variables, name) ? error("Variable $name is already a vector variable in the model") : nothing
throw_if_tensor_variable(context::Context, name::Symbol) =
    haskey(context.tensor_variables, name) ? error("Variable $name is already a tensor variable in the model") : nothing