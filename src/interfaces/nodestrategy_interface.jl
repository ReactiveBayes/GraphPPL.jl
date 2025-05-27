"""
    FactorNodeStrategy

Abstract interface defining strategies for factor node interpretation in GraphPPL.jl.
This defines how factor nodes should be interpreted, behaved, and parametrized,
allowing for different strategies to be integrated with the core modeling framework.
"""
abstract type FactorNodeStrategy end

"""
    get_aliases(strategy::FactorNodeStrategy, fform)

Returns a collection of aliases for `fform` specific to the chosen strategy.
This function must be implemented by concrete strategy subtypes.
"""
function get_aliases end

get_aliases(strategy::S, fform) where {S <: FactorNodeStrategy} =
    error("Strategy $(typeof(strategy)) must implement a method for `get_aliases` for `$(fform)`.")
get_aliases(model::FactorGraphModelInterface, fform::F) where {F} = get_aliases(get_strategy(model), fform)

"""
    get_factor_alias(strategy::FactorNodeStrategy, fform, interfaces)

Returns the specific alias for a given `fform` and `interfaces` combination,
according to the chosen strategy.
This function must be implemented by concrete strategy subtypes.
"""
function get_factor_alias end

get_factor_alias(strategy::S, fform, interfaces) where {S <: FactorNodeStrategy} =
    error("Strategy $(typeof(strategy)) must implement a method for `get_factor_alias` for `$(fform)` and `$(interfaces)`.")
get_factor_alias(model::FactorGraphModelInterface, fform::F, interfaces) where {F} =
    get_factor_alias(get_strategy(model), fform, interfaces)

"""
    get_interfaces(strategy::FactorNodeStrategy, fform, ninterfaces)

Returns the interface specification (e.g., names, types) for a given `fform`
and a specific number of interfaces `ninterfaces`, according to the strategy.
`ninterfaces` is typically an `Integer` or `StaticInt`.
This function must be implemented by concrete strategy subtypes.
"""
function get_interfaces end

get_interfaces(strategy::S, fform, ninterfaces) where {S <: FactorNodeStrategy} = error(
    "Strategy $(typeof(strategy)) must implement a method for `get_interfaces` for `$(fform)` and `$(ninterfaces)` number of interfaces."
)
get_interfaces(model::FactorGraphModelInterface, fform::F, ninterfaces) where {F} = get_interfaces(get_strategy(model), fform, ninterfaces)

"""
    get_interface_aliases(strategy::FactorNodeStrategy, fform)

Returns the aliases for interfaces of a given `fform`, according to the strategy.
This function must be implemented by concrete strategy subtypes.
"""
function get_interface_aliases end

get_interface_aliases(strategy::S, fform) where {S <: FactorNodeStrategy} =
    error("Strategy $(typeof(strategy)) must implement a method for `get_interface_aliases` for `$(fform)`.")
get_interface_aliases(model::FactorGraphModelInterface, fform::F) where {F} = get_interface_aliases(get_strategy(model), fform)

"""
    get_default_parametrization(strategy::FactorNodeStrategy, nodetype, fform, rhs)

Returns the default parametrization for a given `fform` and `rhs` (right-hand side of an expression),
considering the `nodetype` and the chosen strategy.
This function must be implemented by concrete strategy subtypes.
"""
function get_default_parametrization end

get_default_parametrization(strategy::S, nodetype, fform, rhs) where {S <: FactorNodeStrategy} = error(
    "Strategy $(typeof(strategy)) must implement a method for `get_default_parametrization` for `$(fform)` (`$(nodetype)`) and `$(rhs)`."
)
get_default_parametrization(model::FactorGraphModelInterface, nodetype, fform::F, rhs) where {F} =
    get_default_parametrization(get_strategy(model), nodetype, fform, rhs)

"""
    get_prettyname(strategy::FactorNodeStrategy, fform)

Returns the pretty name for a given `fform`, according to the strategy.
This function must be implemented by concrete strategy subtypes.
"""
function get_prettyname end

get_prettyname(strategy::S, fform) where {S <: FactorNodeStrategy} =
    error("Strategy $(typeof(strategy)) must implement a method for `get_prettyname` for `$(fform)`.")
get_prettyname(model::FactorGraphModelInterface, fform) = get_prettyname(get_strategy(model), fform)

"""
    instantiate(strategy_type::Type{<:FactorNodeStrategy})

Instantiates a default strategy object of the specified `strategy_type`.
This function must be implemented for each concrete strategy type that subtypes `FactorNodeStrategy`.

# Arguments
- `strategy_type::Type{<:FactorNodeStrategy}`: The type of the strategy to instantiate.

# Returns
- An instance of the specified `strategy_type`.
"""
function instantiate end

instantiate(strategy_type::Type{S}) where {S <: FactorNodeStrategy} =
    error("Strategy of type $strategy_type must implement a method for `instantiate`.")

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
    get_node_type(strategy::FactorNodeStrategy, fform)

Returns a `NodeType` object (`Atomic` or `Composite`) for a given strategy and `fform`.
This function must be implemented by concrete strategy subtypes if the default error is not desired.
"""
function get_node_type(strategy::S, fform) where {S <: FactorNodeStrategy}
    error("Strategy $(typeof(strategy)) must implement a method for `get_node_type` for `$(fform)`.")
end
get_node_type(model::FactorGraphModelInterface, fform) = get_node_type(get_strategy(model), fform)

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
    get_node_behaviour(strategy::FactorNodeStrategy, fform)

Returns a `NodeBehaviour` object (`Deterministic` or `Stochastic`) for a given strategy and `fform`.
This function must be implemented by concrete strategy subtypes if the default error is not desired.
"""
function get_node_behaviour(strategy::S, fform) where {S <: FactorNodeStrategy}
    error("Strategy $(typeof(strategy)) must implement a method for `get_node_behaviour` for `$(fform)`.")
end
get_node_behaviour(model::FactorGraphModelInterface, fform) = get_node_behaviour(get_strategy(model), fform)
