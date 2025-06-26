
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

    # Insert the child into the parent's children dictionary
    if haskey(parent.children, fform)
        push!(parent.children[fform], child)
    else
        set!(parent.children, fform, [child])
    end

    foreach(pairs(markov_blanket)) do (name_in_child, object_in_parent)
        # All other types of objects are assumed to be constants, 
        # so we don't need to save them in the context
        if object_in_parent isa ProxyLabel
            set!(child.proxies, name_in_child, object_in_parent)
        end
    end
    return child
end

function has_children(context::Context, fform::F) where {F}
    return haskey(context.children, fform)
end

function has_children(context::Context, fform::F, index) where {F}
    return haskey(context.children, fform) && isassigned(context.children[fform], index)
end

function get_children(context::Context, fform::F) where {F}
    return context.children[fform]
end

function get_children(context::Context, fform::F, index) where {F}
    return context.children[fform][index]
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

function get_variable_or_collection(c::Context, key::Symbol, dimensionality::StaticInt{0})
    if haskey(c.individual_variables, key)
        return c.individual_variables[key]
    elseif haskey(c.proxies, key)
        return c.proxies[key]
    end
    throw(KeyError(key))
end

function get_variable_or_collection(c::Context, key::Symbol, dimensionality::StaticInt{1})
    if haskey(c.vector_variables, key)
        return c.vector_variables[key]
    elseif haskey(c.proxies, key)
        return c.proxies[key]
    end
    throw(KeyError(key))
end

function get_variable_or_collection(c::Context, key::Symbol, dimensionality::StaticInt{N}) where {N}
    if haskey(c.tensor_variables, key)
        return c.tensor_variables[key]
    elseif haskey(c.proxies, key)
        return c.proxies[key]
    end
    throw(KeyError(key))
end

function get_variable(c::Context, key::Symbol, index::Index{0})
    return c.individual_variables[key]
end

function get_variable(c::Context, key::Symbol, index::Index{1})
    return c.vector_variables[key][index.indices[1]]
end

function get_variable(c::Context, key::Symbol, index::Index{N}) where {N}
    return c.tensor_variables[key][index.indices...]
end

function has_variable(c::Context, key::Symbol, index::Index{0})
    return haskey(c.individual_variables, key) || haskey(c.proxies, key)
end

function has_variable(c::Context, key::Symbol, index::Index{1})
    return haskey(c.vector_variables, key) && isassigned(c.vector_variables[key], index.indices[1])
end

function has_variable(c::Context, key::Symbol, index::Index{N}) where {N}
    return haskey(c.tensor_variables, key) && isassigned(c.tensor_variables[key], index.indices...)
end

function set_variable!(c::Context, val::VariableNodeLabel, key::Symbol, index::Index{0})
    set!(c.individual_variables, key, val)
end

function set_variable!(c::Context, val::VariableNodeLabel, key::Symbol, index::Index{1})
    if !haskey(c.vector_variables, key)
        new_array = ResizableArray(VariableNodeLabel, Val(1))
        new_array[index.indices[1]] = val
        set!(c.vector_variables, key, new_array)
    else
        c.vector_variables[key][index.indices[1]] = val
    end
end

function set_variable!(c::Context, val::VariableNodeLabel, key::Symbol, index::Index{N}) where {N}
    if !haskey(c.tensor_variables, key)
        new_array = ResizableArray(VariableNodeLabel, Val(N))
        new_array[index.indices...] = val
        set!(c.tensor_variables, key, new_array)
    else
        c.tensor_variables[key][index.indices...] = val
    end
end

function set_variable!(c::Context, val::ProxyLabel, key::Symbol, index::Index{0})
    set!(c.proxies, key, val)
end

function set_variable!(c::Context, val::ProxyLabel, key::Symbol, index::Index{N}) where {N}
    error("Proxy labels cannot be set at an index, with dimensionality $N")
end

function has_factor(context::Context, functional_form)
    return haskey(context.factor_nodes, functional_form)
end

function has_factor(context::Context, functional_form, index)
    return (haskey(context.factor_nodes, functional_form) && isassigned(context.factor_nodes[functional_form], index))
end

function get_factor(c::Context, functional_form)
    return c.factor_nodes[functional_form]
end

function get_factor(c::Context, functional_form, index)
    return c.factor_nodes[functional_form][index]
end

function set_factor!(c::Context, factor::FactorNodeLabel, functional_form::F) where {F}
    if haskey(c.factor_nodes, functional_form)
        push!(c.factor_nodes[functional_form], factor)
        return length(c.factor_nodes[functional_form])
    else
        set!(c.factor_nodes, functional_form, [factor])
        return 1
    end
end

throw_if_individual_variable(context::Context, name::Symbol) =
    haskey(context.individual_variables, name) ? error("Variable $name is already an individual variable in the model") : nothing
throw_if_vector_variable(context::Context, name::Symbol) =
    haskey(context.vector_variables, name) ? error("Variable $name is already a vector variable in the model") : nothing
throw_if_tensor_variable(context::Context, name::Symbol) =
    haskey(context.tensor_variables, name) ? error("Variable $name is already a tensor variable in the model") : nothing