"""
    DefaultBackend 

A default backend that is used in the `GraphPPL.@model` macro when no backend is specified explicitly.
"""
struct DefaultBackend end

function model_macro_interior_pipelines(::DefaultBackend)
    return (
        check_reserved_variable_names_model,
        warn_datavar_constvar_randomvar,
        # The `compose_simple_operators_with_brackets` pipeline is a workaround for 
        # `RxInfer` inference backend, which cannot handle the multi-argument operators
        # TODO (bvdmitri): Move this to an RxInfer specific backend
        compose_simple_operators_with_brackets,
        save_expression_in_tilde,
        convert_deterministic_statement,
        convert_local_statement,
        convert_to_kwargs_expression,
        add_get_or_create_expression,
        convert_anonymous_variables,
        replace_begin_end,
        convert_tilde_expression
    )
end

# By default we assume everything is a `Deterministic` node, e.g. `Matrix` or `Digonal` or `sqrt`
GraphPPL.NodeBehaviour(::DefaultBackend, _) = GraphPPL.Deterministic()

# By default we assume that types and functions are `Atomic` nodes, `Composite` nodes should be specified explicitly in the `@model` macro
GraphPPL.NodeType(::DefaultBackend, ::Type) = GraphPPL.Atomic()
GraphPPL.NodeType(::DefaultBackend, ::F) where {F <: Function} = GraphPPL.Atomic()
GraphPPL.aliases(::DefaultBackend, f) = (f,)

# Placeholder function that is defined for all Composite nodes and is invoked when inferring what interfaces are missing when a node is called
GraphPPL.interfaces(::DefaultBackend, ::F, ::StaticInt{1}) where {F} = StaticInterfaces((:out,))
GraphPPL.interfaces(::DefaultBackend, ::F, _) where {F} = StaticInterfaces((:out, :in))

# By default all factors are not aliased, e.g. `Normal` remains `Normal`
GraphPPL.factor_alias(::DefaultBackend, f::F, interfaces) where {F} = f