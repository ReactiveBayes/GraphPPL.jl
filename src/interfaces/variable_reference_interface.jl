"""
    VariableReferenceInterface

An abstract type for lazy variable references in the model. 
Concrete implementations allow for postponed creation and dynamic shaping of variables.
"""
abstract type VariableReferenceInterface end

function create_variable_reference(
    nodetype::NodeType, model::FactorGraphModelInterface, context::ContextInterface, name::Symbol, index::Tuple
)
    throw(GraphPPLInterfaceNotImplemented(create_variable_reference, (typeof(nodetype), typeof(model))))
end

function unroll(proxy::ProxyLabelInterface, ref::VariableReferenceInterface, index, maycreate::Union{True, False}, liftedindex)
    throw(GraphPPLInterfaceNotImplemented(unroll, (typeof(proxy), typeof(ref))))
end

function getifcreated(model::FactorGraphModelInterface, context::ContextInterface, ref::VariableReferenceInterface)
    throw(GraphPPLInterfaceNotImplemented(getifcreated, (typeof(model), typeof(ref))))
end

function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, ref::VariableReferenceInterface, index)
    throw(GraphPPLInterfaceNotImplemented(getorcreate!, (typeof(model), typeof(ref))))
end

function get_context(ref::VariableReferenceInterface)
    throw(GraphPPLInterfaceNotImplemented(get_context, typeof(ref)))
end

# """
#     create_variable_reference(
#         nodetype::NodeType, 
#         model::FactorGraphModelInterface, 
#         context::ContextInterface, 
#         options::NodeCreationOptions, 
#         name::Symbol, 
#         index::Tuple
#     ) -> AbstractVariableReference

# Creates an instance of an `AbstractVariableReference`. 
# The `nodetype` (e.g., `Atomic` or `Composite`) can hint at the creation strategy (e.g., eager or lazy).

# This function defines the interface, concrete types should implement a method for this.
# """
# function create_variable_reference(
#     nodetype::Any, # Should ideally be NodeType from GraphPPL.Core
#     model::FactorGraphModelInterface,
#     context::ContextInterface,
#     options::NodeCreationOptions,
#     name::Symbol,
#     index::Tuple
# )
#     throw(GraphPPLInterfaceNotImplemented(create_variable_reference, (typeof(nodetype), typeof(model))))
# end

# """
#     unroll(
#         proxy::ProxyLabelInterface, 
#         ref::AbstractVariableReference, 
#         index, 
#         maycreate::Union{True, False}, 
#         liftedindex
#     )

# Unrolls or resolves the variable reference `ref` based on the provided `proxy`, `index`, and `maycreate` flag.
# `liftedindex` is the potentially transformed index for creation or retrieval.

# This function defines the interface, concrete types should implement a method for this.
# """
# function unroll(
#     proxy::ProxyLabelInterface,
#     ref::AbstractVariableReference,
#     index::Any,
#     maycreate::Any, # Should ideally be Union{True, False} from GraphPPL.Core.Utils
#     liftedindex::Any
# )
#     throw(GraphPPLInterfaceNotImplemented(unroll, (typeof(proxy), typeof(ref))))
# end

# """
#     getifcreated(model::FactorGraphModelInterface, context::ContextInterface, ref::AbstractVariableReference)
#     getifcreated(model::FactorGraphModelInterface, context::ContextInterface, ref::AbstractVariableReference, index)

# Retrieves the variable represented by `ref` if it has already been instantiated in the `model` within the given `context`.
# The method with `index` attempts to retrieve a specific part of an indexed variable reference.
# Returns the instantiated variable or collection, or potentially an error/nothing if not found.

# This function defines the interface, concrete types should implement methods for this.
# """
# function getifcreated(model::FactorGraphModelInterface, context::ContextInterface, ref::AbstractVariableReference)
#     throw(GraphPPLInterfaceNotImplemented(getifcreated, (typeof(model), typeof(ref))))
# end

# function getifcreated(model::FactorGraphModelInterface, context::ContextInterface, ref::AbstractVariableReference, index::Any)
#     throw(GraphPPLInterfaceNotImplemented(getifcreated, (typeof(model), typeof(ref))))
# end

# """
#     getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, ref::AbstractVariableReference, index)

# Retrieves the variable represented by `ref` if it exists, or creates it in the `model` and `context` if it does not.
# The `index` specifies the particular instance or part of the variable to get or create.
# The creation process uses options and naming information encapsulated within the `ref`.

# This function defines the interface, concrete types should implement a method for this.
# """
# function getorcreate!(model::FactorGraphModelInterface, context::ContextInterface, ref::AbstractVariableReference, index::Any)
#     throw(GraphPPLInterfaceNotImplemented(getorcreate!, (typeof(model), typeof(ref))))
# end