"""
    FactorGraphBackendInterface

Abstract interface for backend-specific operations in GraphPPL.jl.
This defines the behavior that any backend implementation must support,
allowing for different computational backends to be integrated with the core
modeling framework.
"""
abstract type FactorGraphBackendInterface end

"""
    get_aliases(backend::FactorGraphBackendInterface, fform)

Returns a collection of aliases for `fform` specific to the `backend`.
This function must be implemented by concrete backend subtypes.
"""
function get_aliases end

get_aliases(backend::B, fform) where {B <: FactorGraphBackendInterface} =
    error("Backend $(typeof(backend)) must implement a method for `get_aliases` for `$(fform)`.")
get_aliases(model::FactorGraphModelInterface, fform::F) where {F} = get_aliases(get_backend(model), fform)

"""
    get_factor_alias(backend::FactorGraphBackendInterface, fform, interfaces)

Returns the specific alias for a given `fform` and `interfaces` combination,
tailored to the provided `backend`.
This function must be implemented by concrete backend subtypes.
"""
function get_factor_alias end

get_factor_alias(backend::B, fform, interfaces) where {B <: FactorGraphBackendInterface} =
    error("The backend $(typeof(backend)) must implement a method for `get_factor_alias` for `$(fform)` and `$(interfaces)`.")
get_factor_alias(model::FactorGraphModelInterface, fform::F, interfaces) where {F} = get_factor_alias(get_backend(model), fform, interfaces)

"""
    get_interfaces(backend::FactorGraphBackendInterface, fform, ninterfaces)

Returns the interface specification (e.g., names, types) for a given `fform`
and a specific number of interfaces `ninterfaces`, according to the `backend`.
`ninterfaces` is typically an `Integer` or `StaticInt`.
This function must be implemented by concrete backend subtypes.
"""
function get_interfaces end

get_interfaces(backend::B, fform, ninterfaces) where {B <: FactorGraphBackendInterface} = error(
    "The backend $(typeof(backend)) must implement a method for `get_interfaces` for `$(fform)` and `$(ninterfaces)` number of interfaces."
)
get_interfaces(model::FactorGraphModelInterface, fform::F, ninterfaces) where {F} = get_interfaces(get_backend(model), fform, ninterfaces)

"""
    get_interface_aliases(backend::FactorGraphBackendInterface, fform)

Returns the aliases for interfaces of a given `fform`, specific to the `backend`.
This function must be implemented by concrete backend subtypes.
"""
function get_interface_aliases end

get_interface_aliases(backend::B, fform) where {B <: FactorGraphBackendInterface} =
    error("The backend $(typeof(backend)) must implement a method for `get_interface_aliases` for `$(fform)`.")
get_interface_aliases(model::FactorGraphModelInterface, fform::F) where {F} = get_interface_aliases(get_backend(model), fform)

"""
    get_default_parametrization(backend::FactorGraphBackendInterface, nodetype, fform, rhs)

Returns the default parametrization for a given `fform` and `rhs` (right-hand side of an expression),
considering the `nodetype` and specific `backend` logic.
This function must be implemented by concrete backend subtypes.
"""
function get_default_parametrization end

get_default_parametrization(backend::B, nodetype, fform, rhs) where {B <: FactorGraphBackendInterface} = error(
    "The backend $(typeof(backend)) must implement a method for `get_default_parametrization` for `$(fform)` (`$(nodetype)`) and `$(rhs)`."
)
get_default_parametrization(model::FactorGraphModelInterface, nodetype, fform::F, rhs) where {F} =
    get_default_parametrization(get_backend(model), nodetype, fform, rhs)
"""
    instantiate(backend_type::Type{<:FactorGraphBackendInterface})

Instantiates a default backend object of the specified `backend_type`.
This function must be implemented for each concrete backend type that subtypes `FactorGraphBackendInterface`.

# Arguments
- `backend_type::Type{<:FactorGraphBackendInterface}`: The type of the backend to instantiate.

# Returns
- An instance of the specified `backend_type`.
"""
function instantiate end

instantiate(backend_type::Type{B}) where {B <: FactorGraphBackendInterface} =
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
    get_node_type(backend::FactorGraphBackendInterface, fform)

Returns a `NodeType` object (`Atomic` or `Composite`) for a given `backend` and `fform`.
This function must be implemented by concrete backend subtypes if the default error is not desired.
"""
function get_node_type(backend::B, fform) where {B <: FactorGraphBackendInterface}
    error("Backend $(typeof(backend)) must implement a method for `get_node_type` for `$(fform)`.")
end
get_node_type(model::FactorGraphModelInterface, fform) = get_node_type(get_backend(model), fform)

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
    get_node_behaviour(backend::FactorGraphBackendInterface, fform)

Returns a `NodeBehaviour` object (`Deterministic` or `Stochastic`) for a given `backend` and `fform`.
This function must be implemented by concrete backend subtypes if the default error is not desired.
"""
function get_node_behaviour(backend::B, fform) where {B <: FactorGraphBackendInterface}
    error("Backend $(typeof(backend)) must implement a method for `get_node_behaviour` for `$(fform)`.")
end
get_node_behaviour(model::FactorGraphModelInterface, fform) = get_node_behaviour(get_backend(model), fform)
