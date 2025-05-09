"""
    ModelInterface

Abstract interface for operations on probabilistic models.
This defines the behavior that any model implementation must support,
regardless of the underlying graph representation.
"""
abstract type ModelInterface end

"""
    NodeLabelInterface

Abstract interface for node labels in a factor graph. This serves as a unified
reference type for both variable and factor nodes, providing a consistent way
to identify nodes regardless of implementation details.
"""
abstract type NodeLabelInterface end

"""
    get_context(model::ModelInterface)

Retrieve the context associated with the model.

The context typically contains information about the model's configuration,
execution environment, or other metadata that influences model behavior.

Returns the context object for the model.
"""
function get_context end

"""
    nv(model::ModelInterface)

Get the number of vertices (nodes) in the model.

Returns an integer representing the total count of nodes in the model's graph.
"""
function nv end

"""
    ne(model::ModelInterface)

Get the number of edges in the model.

Returns an integer representing the total count of edges connecting nodes in the model's graph.
"""
function ne end

# Node Label Operations

"""
    is_variable_node(model::ModelInterface, label::NodeLabelInterface)

Check if the node label refers to a variable node in the model.

Returns a boolean indicating if the node is a variable node.
"""
function is_variable_node end

"""
    is_factor_node(model::ModelInterface, label::NodeLabelInterface)

Check if the node label refers to a factor node in the model.

Returns a boolean indicating if the node is a factor node.
"""
function is_factor_node end

# Core Model Operations

"""
    add_variable!(model::ModelInterface, data::VariableNodeDataInterface)

Add a variable node to the model with the given data.

Returns the node label for the added variable.
"""
function add_variable! end

"""
    add_factor!(model::ModelInterface, data::FactorNodeDataInterface)

Add a factor node to the model with the given data.

Returns the node label for the added factor.
"""
function add_factor! end

"""
    add_edge!(model::ModelInterface, source::NodeLabelInterface, destination::NodeLabelInterface, edge_data::EdgeInterface)

Connect two nodes in the model with an edge containing the specified data.

Returns a reference to the created edge.
"""
function add_edge! end

"""
    has_edge(model::ModelInterface, source::NodeLabelInterface, destination::NodeLabelInterface)

Check if the model has an edge between the specified source and destination nodes.

Returns a boolean indicating presence of the edge.
"""
function has_edge end

"""
    get_variables(model::ModelInterface)

Get all variable nodes in the model.

Returns an iterable of node labels representing all variable nodes in the model.
"""
function get_variables end

"""
    get_factors(model::ModelInterface)

Get all factor nodes in the model.

Returns an iterable of node labels representing all factor nodes in the model.
"""
function get_factors end

"""
    get_variable_data(model::ModelInterface, label::NodeLabelInterface)

Get the variable node data identified by the given label.
Will throw an error if the label does not refer to a variable node.

Returns the variable node data if found, or nothing.
"""
function get_variable_data end

"""
    get_factor_data(model::ModelInterface, label::NodeLabelInterface)

Get the factor node data identified by the given label.
Will throw an error if the label does not refer to a factor node.

Returns the factor node data if found, or nothing.
"""
function get_factor_data end

"""
    get_edge_data(model::ModelInterface, source::NodeLabelInterface, destination::NodeLabelInterface)

Get the data of the edge between the specified source and destination nodes.

Returns the edge data if found, or nothing.
"""
function get_edge_data end

"""
    variable_neighbors(model::ModelInterface, label::NodeLabelInterface)

Get all neighboring variable nodes of the specified factor node.

Returns an iterable of node labels.
"""
function variable_neighbors end

"""
    factor_neighbors(model::ModelInterface, label::NodeLabelInterface)

Get all neighboring factor nodes of the specified variable node.

Returns an iterable of node labels.
"""
function factor_neighbors end

"""
    get_backend(model::ModelInterface)

Get the backend associated with the model.

Returns the backend object used by the model for node behavior and type definitions.
"""
function get_backend end

"""
    get_plugins(model::ModelInterface)

Get the plugins collection associated with the model.

Returns the plugins collection object that contains all plugins enabled for the model.
"""
function get_plugins end

"""
    get_source(model::ModelInterface)

Get the source code representation of the model.

Returns the source object (typically a String) representing the original source code
from which the model was created.
"""
function get_source end

"""
    save_model(file::AbstractString, model::ModelInterface)

Save the model to a file or other storage.
"""
function save_model end

"""
    load_model(file::AbstractString, t::Type{<:ModelInterface})

Load a model from a file or other storage.
"""
function load_model end

"""
    prune_model!(model::ModelInterface)

Remove all isolated nodes from the model.

Returns the updated model.
"""
function prune_model! end

"""
    make_variable_data(::Type{M}, context::Any, name::Symbol, index::Any;
                         kind::Symbol = :random, # Using :random as a common default
                         link::Any = nothing,
                         value::Any = nothing,
                         extra_properties::NamedTuple = NamedTuple()) where {M <: ModelInterface}

Constructs a type-stable data payload for a variable node, specific to model type `M`.
This payload is intended to be passed to `GraphPPL.add_variable!(model, payload)`.

# Arguments
- `::Type{M}`: The specific model interface implementation type.
- `context::Any`: The context for this variable data. (Using Any for now, can be refined to a specific Context type if available globally)
- `name::Symbol`: The name of the variable.
- `index::Any`: The index associated with the variable.
- `kind::Symbol`: The kind of the variable (e.g., :random, :data, :constant). Defaults to `:random`.
- `link::Any`: A link to another entity, if applicable. Defaults to `nothing`.
- `value::Any`: A pre-assigned value, if applicable. Defaults to `nothing`.
- `extra_properties::NamedTuple`: Additional plugin-specific or custom properties.

# Returns
- An instance of a concrete, type-stable variable data structure.
"""
function make_variable_data end

"""
    make_factor_data(::Type{M}, context::Any, fform::Any;
                       extra_properties::NamedTuple = NamedTuple()) where {M <: ModelInterface}

Constructs a type-stable data payload for a factor node, specific to model type `M`.
This payload is intended to be passed to `GraphPPL.add_factor!(model, payload)`.

# Arguments
- `::Type{M}`: The specific model interface implementation type.
- `context::Any`: The context for this factor data. (Using Any for now)
- `fform::Any`: The functional form of the factor.
- `extra_properties::NamedTuple`: Additional plugin-specific or custom properties.

# Returns
- An instance of a concrete, type-stable factor data structure.
"""
function make_factor_data end

"""
    make_edge_data(::Type{M}, name::Symbol, index::Any) where {M <: ModelInterface}

Constructs a data payload for an edge, specific to model type `M`.
This payload is intended to be passed to `GraphPPL.add_edge!(model, source, destination, payload)`.

# Arguments
- `::Type{M}`: The specific model interface implementation type.
- `name::Symbol`: A name associated with the edge, often representing an interface or argument name on the factor side.
- `index::Any`: An index, if the edge connects to an indexed interface (e.g., for vector-valued arguments).

# Returns
- An instance of a concrete edge data structure (which should be a subtype of `EdgeInterface`).
"""
function make_edge_data end

# Graph Creation Operations
"""
    create_model(::Type{T}; plugins=default_plugins(), backend=default_backend(T), source=nothing) where {T <: ModelInterface}

Create a new model with the specified plugins, backend, and source.
Returns a newly created model instance.
"""
function create_model end
