import Graphs

"""
    FactorGraphModelInterface

Abstract interface for operations on probabilistic models.
This defines the behavior that any model implementation must support,
regardless of the underlying graph representation.
"""
abstract type FactorGraphModelInterface end

"""
    NodeLabelInterface

Abstract interface for node labels in a factor graph. This serves as a unified
reference type for both variable and factor nodes, providing a consistent way
to identify nodes regardless of implementation details.
"""
abstract type NodeLabelInterface end

"""
    get_context(model::M) where {M<:FactorGraphModelInterface}

Retrieve the context associated with the model.

The context typically contains information about the model's configuration,
execution environment, or other metadata that influences model behavior.

Returns the context object for the model.
"""
function get_context(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_context, M, FactorGraphModelInterface))
end

"""
    Graphs.nv(model::M) where {M<:FactorGraphModelInterface}

Get the number of vertices (nodes) in the model.

Returns an integer representing the total count of nodes in the model's graph.

Implementations must extend this method from Graphs.jl.
"""
Graphs.nv(model::M) where {M <: FactorGraphModelInterface} = throw(GraphPPLInterfaceNotImplemented(Graphs.nv, M, FactorGraphModelInterface))

"""
    Graphs.ne(model::M) where {M<:FactorGraphModelInterface}

Get the number of edges in the model.

Returns an integer representing the total count of edges connecting nodes in the model's graph.

Implementations must extend this method from Graphs.jl.
"""
Graphs.ne(model::M) where {M <: FactorGraphModelInterface} = throw(GraphPPLInterfaceNotImplemented(Graphs.ne, M, FactorGraphModelInterface))

# Node Label Operations

"""
    is_variable_node(model::M, label::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Check if the node label refers to a variable node in the model.

Returns a boolean indicating if the node is a variable node.
"""
function is_variable_node(model::M, label::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(is_variable_node, M, FactorGraphModelInterface))
end

"""
    is_factor_node(model::M, label::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Check if the node label refers to a factor node in the model.

Returns a boolean indicating if the node is a factor node.
"""
function is_factor_node(model::M, label::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(is_factor_node, M, FactorGraphModelInterface))
end

# Core Model Operations

"""
    add_variable!(model::M, data::VariableNodeDataInterface) where {M<:FactorGraphModelInterface}

Add a variable node to the model with the given data.

Returns the node label for the added variable.
"""
function add_variable!(model::M, data::VariableNodeDataInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(add_variable!, M, FactorGraphModelInterface))
end

"""
    add_factor!(model::M, data::FactorNodeDataInterface) where {M<:FactorGraphModelInterface}

Add a factor node to the model with the given data.

Returns the node label for the added factor.
"""
function add_factor!(model::M, data::FactorNodeDataInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(add_factor!, M, FactorGraphModelInterface))
end

"""
    add_edge!(model::M, source::NodeLabelInterface, destination::NodeLabelInterface, edge_data::EdgeInterface) where {M<:FactorGraphModelInterface}

Connect two nodes in the model with an edge containing the specified data.

Returns a reference to the created edge.
"""
function add_edge!(
    model::M, source::NodeLabelInterface, destination::NodeLabelInterface, edge_data::EdgeInterface
) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(add_edge!, M, FactorGraphModelInterface))
end

"""
    has_edge(model::M, source::NodeLabelInterface, destination::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Check if the model has an edge between the specified source and destination nodes.

Returns a boolean indicating presence of the edge.
"""
function has_edge(model::M, source::NodeLabelInterface, destination::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(has_edge, M, FactorGraphModelInterface))
end

"""
    get_variables(model::M) where {M<:FactorGraphModelInterface}

Get all variable nodes in the model.

Returns an iterable of node labels representing all variable nodes in the model.
"""
function get_variables(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variables, M, FactorGraphModelInterface))
end

"""
    get_factors(model::M) where {M<:FactorGraphModelInterface}

Get all factor nodes in the model.

Returns an iterable of node labels representing all factor nodes in the model.
"""
function get_factors(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factors, M, FactorGraphModelInterface))
end

"""
    get_variable_data(model::M, label::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Get the variable node data identified by the given label.
Will throw an error if the label does not refer to a variable node.

Returns the variable node data if found, or nothing.
"""
function get_variable_data(model::M, label::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable_data, M, FactorGraphModelInterface))
end

"""
    get_factor_data(model::M, label::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Get the factor node data identified by the given label.
Will throw an error if the label does not refer to a factor node.

Returns the factor node data if found, or nothing.
"""
function get_factor_data(model::M, label::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_data, M, FactorGraphModelInterface))
end

"""
    get_edge_data(model::M, source::NodeLabelInterface, destination::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Get the data of the edge between the specified source and destination nodes.

Returns the edge data if found, or nothing.
"""
function get_edge_data(model::M, source::NodeLabelInterface, destination::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_edge_data, M, FactorGraphModelInterface))
end

"""
    variable_neighbors(model::M, label::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Get all neighboring variable nodes of the specified factor node.

Returns an iterable of node labels.
"""
function variable_neighbors(model::M, label::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(variable_neighbors, M, FactorGraphModelInterface))
end

"""
    factor_neighbors(model::M, label::NodeLabelInterface) where {M<:FactorGraphModelInterface}

Get all neighboring factor nodes of the specified variable node.

Returns an iterable of node labels.
"""
function factor_neighbors(model::M, label::NodeLabelInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(factor_neighbors, M, FactorGraphModelInterface))
end

"""
    get_backend(model::M) where {M<:FactorGraphModelInterface}

Get the backend associated with the model.

Returns the backend object used by the model for node behavior and type definitions.
"""
function get_backend(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_backend, M, FactorGraphModelInterface))
end

"""
    get_plugins(model::M) where {M<:FactorGraphModelInterface}

Get the plugins collection associated with the model.

Returns the plugins collection object that contains all plugins enabled for the model.
"""
function get_plugins(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_plugins, M, FactorGraphModelInterface))
end

"""
    get_source_code(model::M) where {M<:FactorGraphModelInterface}

Get the source code representation of the model.

Returns the source object (typically a String) representing the original source code
from which the model was created.
"""
function get_source_code(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_source_code, M, FactorGraphModelInterface))
end

"""
    save_model(file::AbstractString, model::M) where {M<:FactorGraphModelInterface}

Save the model to a file or other storage.
"""
function save_model(file::AbstractString, model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(save_model, M, FactorGraphModelInterface))
end

"""
    load_model(file::AbstractString, t::Type{<:FactorGraphModelInterface})

Load a model from a file or other storage.
"""
function load_model(file::AbstractString, t::Type{<:FactorGraphModelInterface})
    throw(GraphPPLInterfaceNotImplemented(load_model, t, FactorGraphModelInterface))
end

"""
    prune_model!(model::M) where {M<:FactorGraphModelInterface}

Remove all isolated nodes from the model.

Returns the updated model.
"""
function prune_model!(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(prune_model!, M, FactorGraphModelInterface))
end

"""
    get_variable_node_type(model::M) where {M<:FactorGraphModelInterface}

Returns the type of variable node data used by this model implementation.
Must return a type that implements VariableNodeDataInterface.
"""
function get_variable_data_type(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable_data_type, M, FactorGraphModelInterface))
end

"""
    make_variable_data(model::M, context::Any, name::Symbol, index::Any;
                      kind::Symbol=:random,
                      link::Any=nothing,
                      value::Any=nothing,
                      metadata::Any=nothing) where {M<:FactorGraphModelInterface}

Creates variable node data for the given model type by first resolving the appropriate
node data type via get_variable_node_type and then constructing it with create_variable_node_data.

# Arguments
- `model::M`: The model interface implementation instance
- `context::Any`: The context for this variable
- `name::Symbol`: The name of the variable
- `index::Any`: The index for this variable (nothing for non-indexed)
- `kind::Symbol`: The kind of variable (defaults to :random)
- `link::Any`: Optional link to other nodes/components
- `value::Any`: Optional pre-assigned value
- `metadata::Any`: Optional additional metadata for extensions

# Returns
A concrete implementation of VariableNodeDataInterface appropriate for the model type
"""
function make_variable_data(
    model::M,
    context::Any,
    name::Symbol,
    index::Any;
    kind::Symbol = :random,
    link::Any = nothing,
    value::Any = nothing,
    metadata::Any = nothing
) where {M <: FactorGraphModelInterface}
    T = get_variable_data_type(model)
    return create_variable_data(T, name, index, kind, link, value, context, metadata)
end

"""
    get_factor_node_type(model::M) where {M<:FactorGraphModelInterface}

Returns the type of factor node data used by this model implementation.
Must return a type that implements FactorNodeDataInterface.
"""
function get_factor_node_type(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_node_type, M, FactorGraphModelInterface))
end

"""
    create_factor_data(model::FactorGraphModelInterface, context, fform; kwargs...)

Create factor node data for the given model, context, and functional form. Additional keyword arguments
can be provided to customize the factor node data creation.

# Arguments
- `model`: The factor graph model interface instance
- `context`: The context for the factor node
- `fform`: The functional form for the factor node

# Keywords
- `kwargs...`: Additional keyword arguments for customizing the factor node data

# Returns
- An instance of factor node data that implements `FactorNodeDataInterface`
"""
function create_factor_data(model::M, context::Any, fform::Any; kwargs...) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(create_factor_data, M, FactorGraphModelInterface))
end

"""
    create_edge_data(model::M, name::Symbol, index::Any) where {M <: FactorGraphModelInterface}

Constructs a data payload for an edge, specific to model type `M`.
This payload is intended to be passed to `GraphPPL.add_edge!(model, source, destination, payload)`.

# Arguments
- `model::M`: The specific model interface implementation instance.
- `name::Symbol`: A name associated with the edge, often representing an interface or argument name on the factor side.
- `index::Any`: An index, if the edge connects to an indexed interface (e.g., for vector-valued arguments).

# Returns
- An instance of a concrete edge data structure (which should be a subtype of `EdgeInterface`).
"""
function create_edge_data(model::M, name::Symbol, index::Any) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(create_edge_data, M, FactorGraphModelInterface))
end

# Graph Creation Operations
"""
    create_model(::Type{T}; plugins=default_plugins(), backend=default_backend(T), source=nothing) where {T <: FactorGraphModelInterface}

Create a new model with the specified plugins, backend, and source.
Returns a newly created model instance.
"""
function create_model(::Type{T}; kwargs...) where {T <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(create_model, T, FactorGraphModelInterface))
end
