"""
    aliases(backend, fform)

Returns a collection of aliases for `fform` depending on the `backend`.
"""
aliases(backend, fform) = error("Backend $backend must implement a method for `aliases` for `$(fform)`.")
aliases(model::AbstractModel, fform::F) where {F} = aliases(getbackend(model), fform)
"""
    factor_alias(backend, fform, interfaces)

Returns the alias for a given `fform` and `interfaces` with a given `backend`.
"""
function factor_alias end

factor_alias(backend, fform, interfaces) =
    error("The backend $backend must implement a method for `factor_alias` for `$(fform)` and `$(interfaces)`.")
factor_alias(model::AbstractModel, fform::F, interfaces) where {F} = factor_alias(getbackend(model), fform, interfaces)

"""
    interfaces(backend, fform, ::StaticInt{N}) where N

Returns the interfaces for a given `fform` and `backend` with a given amount of interfaces `N`.
"""
function interfaces end

interfaces(backend, fform, ninputs) =
    error("The backend $(backend) must implement a method for `interfaces` for `$(fform)` and `$(ninputs)` number of inputs.")
interfaces(model::AbstractModel, fform::F, ninputs) where {F} = interfaces(getbackend(model), fform, ninputs)

"""
    interface_aliases(backend, fform)

Returns the aliases for a given `fform` and `backend`.
"""
function interface_aliases end

interface_aliases(backend, fform) = error("The backend $backend must implement a method for `interface_aliases` for `$(fform)`.")
interface_aliases(model::AbstractModel, fform::F) where {F} = interface_aliases(getbackend(model), fform)

"""
    default_parametrization(backend, fform, rhs)

Returns the default parametrization for a given `fform` and `backend` with a given `rhs`.
"""
function default_parametrization end

default_parametrization(backend, nodetype, fform, rhs) =
    error("The backend $backend must implement a method for `default_parametrization` for `$(fform)` (`$(nodetype)`) and `$(rhs)`.")
default_parametrization(model::AbstractModel, nodetype, fform::F, rhs) where {F} =
    default_parametrization(getbackend(model), nodetype, fform, rhs)

"""
    instantiate(::Type{Backend})

Instantiates a default backend object of the specified type. Should be implemented for all backends.
"""
instantiate(backendtype) = error("The backend of type $backendtype must implement a method for `instantiate`.")