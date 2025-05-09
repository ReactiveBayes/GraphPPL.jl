"""
    BackendInterface

Abstract interface for backend-specific operations in GraphPPL.jl.
This defines the behavior that any backend implementation must support,
allowing for different computational backends to be integrated with the core
modeling framework.
"""
abstract type BackendInterface end

"""
    aliases(backend::BackendInterface, fform)

Returns a collection of aliases for `fform` specific to the `backend`.
This function must be implemented by concrete backend subtypes.
"""
function aliases end

aliases(backend::BackendInterface, fform) = error("Backend $(typeof(backend)) must implement a method for `aliases` for `$(fform)`.")
aliases(model::ModelInterface, fform::F) where {F} = aliases(get_backend(model), fform)

"""
    factor_alias(backend::BackendInterface, fform, interfaces)

Returns the specific alias for a given `fform` and `interfaces` combination,
tailored to the provided `backend`.
This function must be implemented by concrete backend subtypes.
"""
function factor_alias end

factor_alias(backend::BackendInterface, fform, interfaces) =
    error("The backend $(typeof(backend)) must implement a method for `factor_alias` for `$(fform)` and `$(interfaces)`.")
factor_alias(model::ModelInterface, fform::F, interfaces) where {F} = factor_alias(get_backend(model), fform, interfaces)

"""
    interfaces(backend::BackendInterface, fform, ninterfaces)

Returns the interface specification (e.g., names, types) for a given `fform`
and a specific number of interfaces `ninterfaces`, according to the `backend`.
`ninterfaces` is typically an `Integer` or `StaticInt`.
This function must be implemented by concrete backend subtypes.
"""
function interfaces end

interfaces(backend::BackendInterface, fform, ninterfaces) = error(
    "The backend $(typeof(backend)) must implement a method for `interfaces` for `$(fform)` and `$(ninterfaces)` number of interfaces."
)
interfaces(model::ModelInterface, fform::F, ninterfaces) where {F} = interfaces(get_backend(model), fform, ninterfaces)

"""
    interface_aliases(backend::BackendInterface, fform)

Returns the aliases for interfaces of a given `fform`, specific to the `backend`.
This function must be implemented by concrete backend subtypes.
"""
function interface_aliases end

interface_aliases(backend::BackendInterface, fform) =
    error("The backend $(typeof(backend)) must implement a method for `interface_aliases` for `$(fform)`.")
interface_aliases(model::ModelInterface, fform::F) where {F} = interface_aliases(get_backend(model), fform)

"""
    default_parametrization(backend::BackendInterface, nodetype, fform, rhs)

Returns the default parametrization for a given `fform` and `rhs` (right-hand side of an expression),
considering the `nodetype` and specific `backend` logic.
This function must be implemented by concrete backend subtypes.
"""
function default_parametrization end

default_parametrization(backend::BackendInterface, nodetype, fform, rhs) = error(
    "The backend $(typeof(backend)) must implement a method for `default_parametrization` for `$(fform)` (`$(nodetype)`) and `$(rhs)`."
)
default_parametrization(model::ModelInterface, nodetype, fform::F, rhs) where {F} =
    default_parametrization(get_backend(model), nodetype, fform, rhs)

"""
    instantiate(backend_type::Type{<:BackendInterface})

Instantiates a default backend object of the specified `backend_type`.
This function must be implemented for each concrete backend type that subtypes `BackendInterface`.

# Arguments
- `backend_type::Type{<:BackendInterface}`: The type of the backend to instantiate.

# Returns
- An instance of the specified `backend_type`.
"""
function instantiate end

instantiate(backend_type::Type{B}) where {B <: BackendInterface} =
    error("The backend of type $backend_type must implement a method for `instantiate`.")

# NodeType and NodeBehaviour definitions moved from src/core/node_types.jl

"""
    NodeType

Abstract type representing either `Composite` or `Atomic` trait for a given object. By default is `Atomic` unless specified otherwise.
"""
abstract type NodeType end

"""
    Composite

`Composite` object used as a trait of structs and functions that are composed of multiple nodes and therefore implement `make_node!`.
"""
struct Composite <: NodeType end

"""
    Atomic
`Atomic` object used as a trait of structs and functions that are composed of a single node and are therefore materialized as a single node in the factor graph.
"""
struct Atomic <: NodeType end

"""
    get_node_type(backend::BackendInterface, fform)

Returns a `NodeType` object (`Atomic` or `Composite`) for a given `backend` and `fform`.
This function must be implemented by concrete backend subtypes if the default error is not desired.
"""
function get_node_type(backend::BackendInterface, fform)
    error("Backend $(typeof(backend)) must implement a method for `get_node_type` for `$(fform)`.")
end
get_node_type(model::ModelInterface, fform) = get_node_type(get_backend(model), fform)

"""
    NodeBehaviour

Abstract type representing either `Deterministic` or `Stochastic` for a given object. By default is `Deterministic` unless specified otherwise.
"""
abstract type NodeBehaviour end

"""
    Stochastic

`Stochastic` object used to parametrize factor node object with stochastic type of relationship between variables.
"""
struct Stochastic <: NodeBehaviour end

"""
    Deterministic

`Deterministic` object used to parametrize factor node object with determinstic type of relationship between variables.
"""
struct Deterministic <: NodeBehaviour end

"""
    get_node_behaviour(backend::BackendInterface, fform)

Returns a `NodeBehaviour` object (`Deterministic` or `Stochastic`) for a given `backend` and `fform`.
This function must be implemented by concrete backend subtypes if the default error is not desired.
"""
function get_node_behaviour(backend::BackendInterface, fform)
    error("Backend $(typeof(backend)) must implement a method for `get_node_behaviour` for `$(fform)`.")
end
get_node_behaviour(model::ModelInterface, fform) = get_node_behaviour(get_backend(model), fform)
