"""
    AnonymousVariable(model, context)

Defines a lazy structure for anonymous variables.
The actual anonymous variables materialize only in `make_node!` upon calling, because it needs arguments to the `make_node!` in order to create proper links.
"""
struct AnonymousVariable{M, C}
    model::M
    context::C
end

Base.broadcastable(v::AnonymousVariable) = Ref(v)

create_anonymous_variable!(model::FactorGraphModelInterface, context::ContextInterface) = AnonymousVariable(model, context)

function materialize_anonymous_variable!(anonymous::AnonymousVariable, fform, args)
    model = anonymous.model
    return materialize_anonymous_variable!(get_node_behaviour(model, fform), model, anonymous.context, fform, args)
end

# Deterministic nodes can create links to variables in the model
# This might be important for better factorization constraints resolution
function materialize_anonymous_variable!(::Deterministic, model::FactorGraphModelInterface, context::ContextInterface, fform, args)
    linked = getindex.(Ref(model), unroll.(filter(is_nodelabel, args)))

    # Check if all links are either `data` or `constants`
    # In this case it is not necessary to create a new random variable, but rather a data variable 
    # with `value = fform`
    link_const, link_const_or_data = reduce(linked; init = (true, true)) do accum, link
        check_is_all_constant, check_is_all_constant_or_data = accum
        check_is_all_constant = check_is_all_constant && anonymous_arg_is_constanst(link)
        check_is_all_constant_or_data = check_is_all_constant_or_data && anonymous_arg_is_constanst_or_data(link)
        return (check_is_all_constant, check_is_all_constant_or_data)
    end

    if !link_const && !link_const_or_data
        # Most likely case goes first, we need to create a new factor node and a new random variable
        (true, add_variable_node!(model, context, NodeCreationOptions(link = linked), VariableNameAnonymous, nothing))
    elseif link_const
        # If all `links` are constant nodes we can evaluate the `fform` here and create another constant rather than creating a new factornode
        val = fform(map(arg -> arg isa NodeLabel ? value(getproperties(model[arg])) : arg, unroll.(args))...)
        (
            false,
            add_variable_node!(
                model, context, NodeCreationOptions(kind = :constant, value = val, link = linked), VariableNameAnonymous, nothing
            )
        )
    elseif link_const_or_data
        # If all `links` are constant or data we can create a new data variable with `fform` attached to it as a value rather than creating a new factornode
        (
            false,
            add_variable_node!(
                model,
                context,
                NodeCreationOptions(kind = :data, value = (fform, unroll.(args)), link = linked),
                VariableNameAnonymous,
                nothing
            )
        )
    else
        # This should not really happen
        error("Unreachable reached in `materialize_anonymous_variable!` for `Deterministic` node behaviour.")
    end
end

anonymous_arg_is_constant(data) = true
anonymous_arg_is_constant(data::VariableNodeDataInterface) = is_constant(getproperties(data))
anonymous_arg_is_constant(data::AbstractArray) = all(anonymous_arg_is_constant, data)

anonymous_arg_is_constant_or_data(data) = is_constant(data)
anonymous_arg_is_constant_or_data(data::VariableNodeDataInterface) =
    let props = getproperties(data)
        is_constant(props) || is_data(props)
    end
anonymous_arg_is_constanst_or_data(data::AbstractArray) = all(anonymous_arg_is_constanst_or_data, data)

function materialize_anonymous_variable!(
    ::Deterministic, model::FactorGraphModelInterface, context::ContextInterface, fform, args::NamedTuple
)
    return materialize_anonymous_variable!(Deterministic(), model, context, fform, values(args))
end

function materialize_anonymous_variable!(::Stochastic, model::FactorGraphModelInterface, context::ContextInterface, fform, _)
    return (true, add_variable_node!(model, context, NodeCreationOptions(), VariableNameAnonymous, nothing))
end