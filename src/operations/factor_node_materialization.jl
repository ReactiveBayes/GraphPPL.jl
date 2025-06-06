abstract type FactorNodeProperties end # TODO: remove this but graphppl really wants this to compile
"""
    add_atomic_factor_node!(model::FactorGraphModelInterface, context::ContextInterface, options::FactorNodeCreationOptions, fform)

Add an atomic factor node to the model with the given name.
The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `FactorNodeData` struct.

Args:
    - `model::FactorGraphModelInterface`: The model to which the node is added.
    - `context::ContextInterface`: The context to which the symbol is added.
    - `options::FactorNodeCreationOptions`: The options for the creation process, used by plugins.
    - `fform::Any`: The functional form of the node.

Returns:
    - The generated label for the node.
"""
function add_atomic_factor_node! end

function add_atomic_factor_node!(
    model::FactorGraphModelInterface, context::ContextInterface, options::FactorNodeCreationOptions, fform::F
) where {F}
    potential_nodedata = create_factor_data(model, fform)
    nodedata = preprocess_factor_node_plugins(model, context, potential_nodedata, options)
    label = add_factor!(model, nodedata)
    set_factor!(context, label, fform)
    return label, nodedata
end

"""
Add a composite factor node to the model with the given name.

The function generates a new symbol for the node and adds it to the model with
the generated symbol as the key and a `FactorNodeData` struct with `is_variable` set to
`false` and `node_name` set to the given name.

Args:
    - `model::FactorGraphModelInterface`: The model to which the node is added.
    - `parent_context::ContextInterface`: The context to which the symbol is added.
    - `context::ContextInterface`: The context of the composite factor node.
    - `node_name::Symbol`: The name of the node.

Returns:
    - The generated id for the node.
"""
function add_composite_factor_node!(
    model::FactorGraphModelInterface, parent_context::ContextInterface, context::ContextInterface, node_name
)
    node_id = generate_factor_nodelabel(parent_context, node_name)
    parent_context[node_id] = context
    return node_id
end

function add_edge!(
    model::FactorGraphModelInterface,
    factor_node_id::FactorNodeLabel,
    variable_node_id::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
    interface_name::Symbol
)
    return add_edge!(model, factor_node_id, variable_node_id, interface_name, nothing)
end

function add_edge!(
    model::FactorGraphModelInterface,
    factor_node_id::FactorNodeLabel,
    variable_node_id::Union{AbstractArray, Tuple, NamedTuple},
    interface_name::Symbol
)
    return add_edge!(model, factor_node_id, variable_node_id, interface_name, 1)
end

add_edge!(
    model::FactorGraphModelInterface,
    factor_node_id::FactorNodeLabel,
    variable_node_id::Union{<:ProxyLabel, <:VariableNodeLabel},
    interface_name::Symbol,
    index
) = add_edge!(model, factor_node_id, unroll(variable_node_id), interface_name, index)

function add_edge!(
    model::FactorGraphModelInterface, factor_node_id::FactorNodeLabel, variable_node_id::VariableNodeLabel, interface_name::Symbol, index
)
    edgedata = create_edge_data(model, interface_name, index)
    edgedata = preprocess_edge_plugins(model, edgedata)
    edge_added = add_edge!(model, variable_node_id, factor_node_id, edgedata)
    if !edge_added
        # Double check if the edge has already been added
        if has_edge(model, variable_node_id, factor_node_id)
            error(
                lazy"Trying to create duplicate edge $(edgedata) between variable $(variable_node_id) and factor node $(factor_node_id). Make sure that all the arguments to the `~` operator are unique (both left hand side and right hand side)."
            )
        else
            error(lazy"Cannot create an edge $(edgedata) between variable $(variable_node_id) and factor node $(factor_node_id).")
        end
    end
    return edge_added
end

function add_edge!(
    model::FactorGraphModelInterface,
    factor_node_id::FactorNodeLabel,
    variable_nodes::Union{AbstractArray, Tuple, NamedTuple},
    interface_name::Symbol,
    index
)
    for variable_node in variable_nodes
        add_edge!(model, factor_node_id, variable_node, interface_name, index)
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
    StaticInterfaces{I}

A type that represents a statically defined set of interfaces for a node in a probabilistic graphical model.
The interfaces are encoded in the type parameter `I` as a tuple of symbols, enabling compile-time reasoning
about interface names and structure.

This implementation provides better performance through type stability and compile-time validation,
but requires that interface names are known at compile time.
"""
struct StaticInterfaces{I} end

StaticInterfaces(I::Tuple) = StaticInterfaces{I}()
Base.getindex(::StaticInterfaces{I}, index) where {I} = I[index]

function Base.convert(::Type{NamedTuple}, ::StaticInterfaces{I}, t::Tuple) where {I}
    return NamedTuple{I}(t)
end

"""
    StaticInterfaceAliases{A}

A type that represents a statically defined set of interface aliases for a node in a probabilistic graphical model.
The aliases are encoded in the type parameter `A` as a tuple of pairs of symbols, where each pair maps an alias
to its corresponding interface name.

This implementation provides better performance through type stability and compile-time validation,
but requires that interface aliases are known at compile time.
"""
struct StaticInterfaceAliases{A} end

StaticInterfaceAliases(A::Tuple) = StaticInterfaceAliases{A}()

interface_aliases(model::FactorGraphModelInterface, fform::F, interfaces::StaticInterfaces) where {F} =
    interface_aliases(interface_aliases(model, fform), interfaces)

function interface_aliases(::StaticInterfaceAliases{aliases}, ::StaticInterfaces{interfaces}) where {aliases, interfaces}
    return StaticInterfaces(
        reduce(aliases; init = interfaces) do acc, alias
            from, to = alias
            return replace(acc, from => to)
        end
    )
end

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
function missing_interfaces(model::FactorGraphModelInterface, fform::F, val, known_interfaces::NamedTuple) where {F}
    return missing_interfaces(interfaces(model, fform, val), StaticInterfaces(keys(known_interfaces)))
end

function missing_interfaces(
    ::StaticInterfaces{all_interfaces}, ::StaticInterfaces{present_interfaces}
) where {all_interfaces, present_interfaces}
    return StaticInterfaces(filter(interface -> interface ∉ present_interfaces, all_interfaces))
end

function prepare_interfaces(model::FactorGraphModelInterface, fform::F, lhs_interface, rhs_interfaces::NamedTuple) where {F}
    missing_interface = missing_interfaces(model, fform, static(length(rhs_interfaces)) + static(1), rhs_interfaces)
    return prepare_interfaces(missing_interface, fform, lhs_interface, rhs_interfaces)
end

function prepare_interfaces(::StaticInterfaces{I}, fform::F, lhs_interface, rhs_interfaces::NamedTuple) where {I, F}
    if !(length(I) == 1)
        error(
            lazy"Expected only one missing interface, got $I of length $(length(I)) (node $fform with interfaces $(keys(rhs_interfaces)))"
        )
    end
    missing_interface = first(I)
    return NamedTuple{(missing_interface, keys(rhs_interfaces)...)}((lhs_interface, values(rhs_interfaces)...))
end

function materialize_interface(model, context, interface)
    return getifcreated(model, context, unroll(interface))
end

function materialze_interfaces(model, context, interfaces)
    return map(interface -> materialize_interface(model, context, interface), interfaces)
end

function sort_interfaces(model::FactorGraphModelInterface, fform::F, defined_interfaces::NamedTuple) where {F}
    return sort_interfaces(interfaces(model, fform, static(length(defined_interfaces))), defined_interfaces)
end

function sort_interfaces(::StaticInterfaces{I}, defined_interfaces::NamedTuple) where {I}
    return defined_interfaces[I]
end

function materialize_factor_node!(
    model::FactorGraphModelInterface, context::ContextInterface, options::FactorNodeCreationOptions, fform::F, interfaces::NamedTuple
) where {F}
    factor_node_id, factor_node_data = add_atomic_factor_node!(model, context, options, fform)
    foreach(pairs(interfaces)) do (interface_name, interface)
        add_edge!(model, factor_node_id, interface, interface_name)
    end
    return factor_node_id, factor_node_data
end

# maybe change name
is_nodelabel(x) = false
is_nodelabel(x::AbstractArray) = any(element -> is_nodelabel(element), x)
is_nodelabel(x::VariableNodeLabel) = true
is_nodelabel(x::ProxyLabel) = true
is_nodelabel(x::VariableRef) = true

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

function make_node!(model::FactorGraphModelInterface, ctx::ContextInterface, fform::F, lhs_interfaces, rhs_interfaces) where {F}
    return make_node!(model, ctx, EmptyFactorNodeCreationOptions, fform, lhs_interfaces, rhs_interfaces)
end

make_node!(
    model::FactorGraphModelInterface, ctx::ContextInterface, options::FactorNodeCreationOptions, fform::F, lhs_interface, rhs_interfaces
) where {F} = make_node!(NodeType(model, fform), model, ctx, options, fform, lhs_interface, rhs_interfaces)

# if it is composite, we assume it should be materialized and it is stochastic
# TODO: shall we not assume that the `Composite` node is necessarily stochastic?
make_node!(
    nodetype::Composite,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces
) where {F} = make_node!(True(), nodetype, Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If a node is an object and not a function, we materialize it as a stochastic atomic node
make_node!(
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces::Nothing
) where {F} = make_node!(True(), Atomic(), Stochastic(), model, ctx, options, fform, lhs_interface, NamedTuple{}())

# If node is Atomic, check stochasticity
make_node!(
    ::Atomic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces
) where {F} = make_node!(Atomic(), NodeBehaviour(model, fform), model, ctx, options, fform, lhs_interface, rhs_interfaces)

#If a node is deterministic, we check if there are any NodeLabel objects in the rhs_interfaces (direct check if node should be materialized)
make_node!(
    atomic::Atomic,
    deterministic::Deterministic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces
) where {F} =
    make_node!(contains_nodelabel(rhs_interfaces), atomic, deterministic, model, ctx, options, fform, lhs_interface, rhs_interfaces)

# If the node should not be materialized (if it's Atomic, Deterministic and contains no NodeLabel objects), we return the `fform` evaluated at the interfaces
# This works only if the `lhs_interface` is `AnonymousVariable` (or the corresponding `ProxyLabel` with `AnonymousVariable` as the proxied variable)
__evaluate_fform(fform::F, args::Tuple) where {F} = fform(args...)
__evaluate_fform(fform::F, args::NamedTuple) where {F} = fform(; args...)
__evaluate_fform(fform::F, args::MixedArguments) where {F} = fform(args.args...; args.kwargs...)

make_node!(
    ::False,
    ::Atomic,
    ::Deterministic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{AnonymousVariable, ProxyLabel{<:T, <:AnonymousVariable} where {T}},
    rhs_interfaces::Union{Tuple, NamedTuple, MixedArguments}
) where {F} = (nothing, __evaluate_fform(fform, rhs_interfaces))

# In case if the `lhs_interface` is something else we throw an error saying that `fform` cannot be instantiated since
# arguments are not stochastic and the `fform` is not stochastic either, thus the usage of `~` is invalid
make_node!(
    ::False,
    ::Atomic,
    ::Deterministic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces::Union{Tuple, NamedTuple, MixedArguments}
) where {F} = error("`$(fform)` cannot be used as a factor node. Both the arguments and the node are not stochastic.")

# If a node is Stochastic, we always materialize.
make_node!(
    ::Atomic,
    ::Stochastic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface,
    rhs_interfaces
) where {F} = make_node!(True(), Atomic(), Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)

function make_node!(
    materialize::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::AnonymousVariable,
    rhs_interfaces
) where {F}
    (noderequired, lhs_materialized) = materialize_anonymous_variable!(lhs_interface, fform, rhs_interfaces)::Tuple{Bool, NodeLabel}
    node_materialized = if noderequired
        node, _ = make_node!(materialize, node_type, behaviour, model, ctx, options, fform, lhs_materialized, rhs_interfaces)
        node
    else
        nothing
    end
    return node_materialized, lhs_materialized
end

# If we have to materialize but the rhs_interfaces argument is not a NamedTuple, we convert it
make_node!(
    materialize::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
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
    GraphPPL.default_parametrization(model, node_type, fform, rhs_interfaces)
)

make_node!(
    ::True,
    node_type::NodeType,
    behaviour::NodeBehaviour,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
    rhs_interfaces::MixedArguments
) where {F} = error("MixedArguments not supported for rhs_interfaces when node has to be materialized")

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
    rhs_interfaces::Tuple{}
) where {F} = make_node!(materialize, node_type, behaviour, model, ctx, options, fform, lhs_interface, NamedTuple{}())

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
    rhs_interfaces::Tuple
) where {F} = error(lazy"Composite node $fform cannot should be called with explicitly naming the interface names")

make_node!(
    materialize::True,
    node_type::Composite,
    behaviour::Stochastic,
    model::FactorGraphModelInterface,
    ctx::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
    rhs_interfaces::NamedTuple
) where {F} = make_node!(Composite(), model, ctx, options, fform, lhs_interface, rhs_interfaces, static(length(rhs_interfaces) + 1))

"""
    make_node!

Make a new factor node in the FactorGraphModelInterface and specified ContextInterface, attach it to the specified interfaces, and return the interface that is on the lhs of the `~` operator.

# Arguments
- `model::FactorGraphModelInterface`: The model to add the node to.
- `ctx::ContextInterface`: The context in which to add the node.
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
    model::FactorGraphModelInterface,
    context::ContextInterface,
    options::FactorNodeCreationOptions,
    fform::F,
    lhs_interface::Union{<:VariableNodeLabel, <:ProxyLabel, <:VariableRef},
    rhs_interfaces::NamedTuple
) where {F}
    aliased_rhs_interfaces = convert(
        NamedTuple, interface_aliases(model, fform, StaticInterfaces(keys(rhs_interfaces))), values(rhs_interfaces)
    )
    aliased_fform = factor_alias(model, fform, StaticInterfaces(keys(aliased_rhs_interfaces)))
    prepared_interfaces = prepare_interfaces(model, aliased_fform, lhs_interface, aliased_rhs_interfaces)
    sorted_interfaces = sort_interfaces(model, aliased_fform, prepared_interfaces)
    interfaces = materialze_interfaces(model, context, sorted_interfaces)
    nodeid, _, _ = materialize_factor_node!(model, context, options, aliased_fform, interfaces)
    return nodeid, unroll(lhs_interface)
end

function add_terminated_submodel!(model::FactorGraphModelInterface, context::ContextInterface, fform, interfaces::NamedTuple)
    return add_terminated_submodel!(
        model, context, FactorNodeCreationOptions((; created_by = () -> :($QuoteNode(fform)))), fform, interfaces
    )
end

function add_terminated_submodel!(
    model::FactorGraphModelInterface, context::ContextInterface, options::FactorNodeCreationOptions, fform, interfaces::NamedTuple
)
    returnval = add_terminated_submodel!(model, context, options, fform, interfaces, static(length(interfaces)))
    returnval!(context, returnval)
    return returnval
end

"""
Add the `fform` as the toplevel model to the `model` and `context` with the specified `interfaces`.
Calls the postprocess logic for the attached plugins of the model. Should be called only once for a given `FactorGraphModelInterface` object.
"""
function add_toplevel_model! end

function add_toplevel_model!(model::FactorGraphModelInterface, fform, interfaces)
    return add_toplevel_model!(model, getcontext(model), fform, interfaces)
end

function add_toplevel_model!(model::FactorGraphModelInterface, context::ContextInterface, fform, interfaces)
    add_terminated_submodel!(model, context, fform, interfaces)
    foreach(getplugins(model)) do plugin
        postprocess_plugin(plugin, model)
    end
    return model
end