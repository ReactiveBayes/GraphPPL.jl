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