import Graphs
using JLD2

"""
    FactorGraphModelInterface

Abstract interface for operations on probabilistic models.
This defines the behavior that any model implementation must support,
regardless of the underlying graph representation.
"""
abstract type FactorGraphModelInterface end

"""

VariableNodeLabel(label::Int)
A node label for a variable node in a factor graph. A simple wrapper around an `Int`.
"""
struct VariableNodeLabel
    label::Int
end

"""
    FactorNodeLabel(label::Int)

A node label for a factor node in a factor graph. A simple wrapper around an `Int`.
"""
struct FactorNodeLabel
    label::Int
end

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

# Core Model Operations

"""
    add_variable!(model::M, data::VariableNodeDataInterface) where {M<:FactorGraphModelInterface}

Add a variable node to the model with the given data. Returns the `VariableNodeLabel` for the added variable.
"""
function add_variable!(model::M, data::VariableNodeDataInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(add_variable!, M, FactorGraphModelInterface))
end

"""
    add_factor!(model::M, data::FactorNodeDataInterface) where {M<:FactorGraphModelInterface}

Add a factor node to the model with the given data. Returns the `FactorNodeLabel` for the added factor.
"""
function add_factor!(model::M, data::FactorNodeDataInterface) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(add_factor!, M, FactorGraphModelInterface))
end

"""
    add_edge!(model::M, variable::VariableNodeLabel, factor::FactorNodeLabel, edge_data::EdgeDataInterface) where {M<:FactorGraphModelInterface}

Connect two nodes in the model with an edge containing the specified data.
Returns a boolean indicating whether the edge was added successfully or not.
"""
function add_edge!(
    model::M, variable::VariableNodeLabel, factor::FactorNodeLabel, edge_data::EdgeDataInterface
) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(add_edge!, M, FactorGraphModelInterface))
end

"""
    has_edge(model::M, variable::VariableNodeLabel, factor::FactorNodeLabel) where {M<:FactorGraphModelInterface}

Check if the model has an edge between the specified variable and factor nodes.
Returns a boolean indicating presence of the edge.
"""
function has_edge(model::M, variable::VariableNodeLabel, factor::FactorNodeLabel) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(has_edge, M, FactorGraphModelInterface))
end

"""
    get_variables(model::M) where {M<:FactorGraphModelInterface}

Get all variable nodes in the model. Returns an iterable of `VariableNodeLabel`s representing all variable nodes in the model.
"""
function get_variables(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variables, M, FactorGraphModelInterface))
end

"""
    get_factors(model::M) where {M<:FactorGraphModelInterface}

Get all factor nodes in the model. Returns an iterable of `FactorNodeLabel`s representing all factor nodes in the model.
"""
function get_factors(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factors, M, FactorGraphModelInterface))
end

"""
    get_variable_data(model::M, label::VariableNodeLabel) where {M<:FactorGraphModelInterface}

Get the variable node data identified by the given label.
Will throw an error if the label does not refer to a variable node.
"""
function get_variable_data(model::M, label::VariableNodeLabel) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable_data, M, FactorGraphModelInterface))
end

"""
    get_factor_data(model::M, label::FactorNodeLabel) where {M<:FactorGraphModelInterface}

Get the factor node data identified by the given label.
Will throw an error if the label does not refer to a factor node.
"""
function get_factor_data(model::M, label::FactorNodeLabel) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_data, M, FactorGraphModelInterface))
end

"""
    get_edge_data(model::M, variable::VariableNodeLabel, factor::FactorNodeLabel) where {M<:FactorGraphModelInterface}

Get the data of the edge between the specified variable and factor nodes.

Returns an instance of edge data that implements `EdgeDataInterface`.
"""
function get_edge_data(model::M, variable::VariableNodeLabel, factor::FactorNodeLabel) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_edge_data, M, FactorGraphModelInterface))
end

"""
    variable_neighbors(model::M, label::FactorNodeLabel) where {M<:FactorGraphModelInterface}

Get all neighboring variable nodes of the specified factor node.
Returns an iterable of `VariableNodeLabel`s.
"""
function variable_neighbors(model::M, label::FactorNodeLabel) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(variable_neighbors, M, FactorGraphModelInterface))
end

"""
    factor_neighbors(model::M, label::VariableNodeLabel) where {M<:FactorGraphModelInterface}

Get all neighboring factor nodes of the specified variable node.
Returns an iterable of `FactorNodeLabel`s.
"""
function factor_neighbors(model::M, label::VariableNodeLabel) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(factor_neighbors, M, FactorGraphModelInterface))
end

"""
    get_node_strategy(model::M) where {M<:FactorGraphModelInterface}

Get the node strategy associated with the model.
"""
function get_node_strategy(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_node_strategy, M, FactorGraphModelInterface))
end

"""
    get_plugins(model::M) where {M<:FactorGraphModelInterface}

Get the plugins collection associated with the model.
"""
function get_plugins(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_plugins, M, FactorGraphModelInterface))
end

"""
    get_source_code(model::M) where {M<:FactorGraphModelInterface}

Get the source code representation of the model.
"""
function get_source_code(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_source_code, M, FactorGraphModelInterface))
end

"""
    save_model(file::AbstractString, model::M) where {M<:FactorGraphModelInterface}

Save the model to a file or other storage.
"""
function save_model(file::AbstractString, model::M) where {M <: FactorGraphModelInterface}
    save(file, model)
end

"""
    load_model(file::AbstractString, t::Type{<:FactorGraphModelInterface})

Load a model from a file or other storage.
"""
function load_model(file::AbstractString, t::Type{<:FactorGraphModelInterface})
    return load(file, t)
end

"""
    get_variable_data_type(model::M) where {M<:FactorGraphModelInterface}

Returns the type of variable node data used by this model implementation.
Must return a type that implements VariableNodeDataInterface.
"""
function get_variable_data_type(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable_data_type, M, FactorGraphModelInterface))
end

"""
    get_factor_data_type(model::M) where {M<:FactorGraphModelInterface}

Returns the type of factor node data used by this model implementation.
Must return a type that implements FactorNodeDataInterface.
"""
function get_factor_data_type(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_data_type, M, FactorGraphModelInterface))
end

"""
    create_variable_data(model::M, name::Symbol, index::Any = nothing, kind::UInt8 = VariableNodeKind.Unspecified, link::Any = nothing, value::Any = nothing)

Create a new variable node data with the given parameters for the specified model.

Returns an instance of variable node data that implements `VariableNodeDataInterface`.
"""
function create_variable_data(
    model::M, name::Symbol, index::Any = nothing, kind::UInt8 = VariableNodeKind.Unspecified, link::Any = nothing, value::Any = nothing
) where {M <: FactorGraphModelInterface}
    T = get_variable_data_type(model)
    return create_variable_data(T, name = name, index = index, kind = kind, link = link, value = value)
end

"""
    create_factor_data(model::FactorGraphModelInterface, fform)

Create factor node data for the given model and functional form.

# Arguments
- `model`: The factor graph model interface instance
- `fform`: The functional form for the factor node

# Returns
- An instance of factor node data that implements `FactorNodeDataInterface`
"""
function create_factor_data(model::M, fform::Any) where {M <: FactorGraphModelInterface}
    T = get_factor_data_type(model)
    return create_factor_data(T, functional_form = fform)
end

"""
    get_edge_data_type(model::M) where {M <: FactorGraphModelInterface}

Returns the type of edge data used by this model implementation.
Must return a type that implements EdgeDataInterface.
"""
function get_edge_data_type(model::M) where {M <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_edge_data_type, M, FactorGraphModelInterface))
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
- An instance of a concrete edge data structure (which should be a subtype of `EdgeDataInterface`).
"""
function create_edge_data(model::M, name::Symbol, index::Any) where {M <: FactorGraphModelInterface}
    T = get_edge_data_type(model)
    return create_edge_data(T; name = name, index = index)
end

"""
    create_model(::Type{T}; plugins=default_plugins(), node_strategy=default_node_strategy(T), source=nothing) where {T <: FactorGraphModelInterface}

Create a new model with the specified plugins, node strategy, and source.
Returns a newly created model instance.
"""
function create_model(::Type{T}; kwargs...) where {T <: FactorGraphModelInterface}
    throw(GraphPPLInterfaceNotImplemented(create_model, T, FactorGraphModelInterface))
end
