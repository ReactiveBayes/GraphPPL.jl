"""
    DefaultBackend 

A default backend that is used in the `GraphPPL.@model` macro when no backend is specified explicitly.
"""
struct DefaultBackend end

function GraphPPL.model_macro_interior_pipelines(::DefaultBackend)
    return (
        GraphPPL.check_reserved_variable_names_model,
        GraphPPL.save_expression_in_tilde,
        GraphPPL.convert_deterministic_statement,
        GraphPPL.convert_local_statement,
        GraphPPL.convert_to_kwargs_expression,
        GraphPPL.add_get_or_create_expression,
        GraphPPL.convert_anonymous_variables,
        GraphPPL.replace_begin_end,
        GraphPPL.convert_tilde_expression
    )
end

# By default we assume everything is a `Deterministic` node, e.g. `Matrix` or `Digonal` or `sqrt`
GraphPPL.NodeBehaviour(::DefaultBackend, _) = GraphPPL.Deterministic()

# By default we assume that types and functions are `Atomic` nodes, `Composite` nodes should be specified explicitly in the `@model` macro
GraphPPL.NodeType(::DefaultBackend, ::Type) = GraphPPL.Atomic()
GraphPPL.NodeType(::DefaultBackend, ::F) where {F <: Function} = GraphPPL.Atomic()
GraphPPL.aliases(::DefaultBackend, f) = (f,)

# Placeholder function that is defined for all Composite nodes and is invoked when inferring what interfaces are missing when a node is called
GraphPPL.interfaces(::DefaultBackend, ::F, ::StaticInt{1}) where {F} = GraphPPL.StaticInterfaces((:out,))
GraphPPL.interfaces(::DefaultBackend, ::F, _) where {F} = GraphPPL.StaticInterfaces((:out, :in))

# By default all factors are not aliased, e.g. `Normal` remains `Normal`
GraphPPL.factor_alias(::DefaultBackend, f::F, interfaces) where {F} = f

# By default we assume that all factors have no aliases for their interfaces
GraphPPL.interface_aliases(::DefaultBackend, _) = GraphPPL.StaticInterfaceAliases(())

# By default only one default parametrization is provided for all nodes, which maps the provided arguments to the `in` interface
# And throws an error for `Composite` nodes since those has to be called with named arguments anyway
default_parametrization(::DefaultBackend, ::Atomic, fform::F, rhs::Tuple) where {F} = (in = rhs,)
default_parametrization(::DefaultBackend, ::Composite, fform::F, rhs) where {F} =
    error("Composite nodes always have to be initialized with named arguments")

"""
    instantiate(::Type{Backend})

instantiates a backend object of the specified type. Should be implemented for all backends.
"""
instantiate(any) = error("Backend of type $any does not implement `instantiate`")
instantiate(::Type{DefaultBackend}) = DefaultBackend()
