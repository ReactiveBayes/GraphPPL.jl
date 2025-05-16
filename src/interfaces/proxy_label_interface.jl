"""
    ProxyLabelInterface

Abstract interface for proxying labels in a probabilistic graphical model.
Proxy labels reference other labels and may create new variables when unrolled.
"""
abstract type ProxyLabelInterface end

"""
    get_name(proxy::P) where {P<:ProxyLabelInterface}

Get the name of the proxy label.
"""
function get_name(proxy::P) where {P <: ProxyLabelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_name, P, ProxyLabelInterface))
end

"""
    get_index(proxy::P) where {P<:ProxyLabelInterface}

Get the index of the proxy label.
"""
function get_index(proxy::P) where {P <: ProxyLabelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_index, P, ProxyLabelInterface))
end

"""
    get_proxied(proxy::P) where {P<:ProxyLabelInterface}

Get the object being proxied.
"""
function get_proxied(proxy::P) where {P <: ProxyLabelInterface}
    throw(GraphPPLInterfaceNotImplemented(get_proxied, P, ProxyLabelInterface))
end

"""
    may_create(proxy::P) where {P<:ProxyLabelInterface}

Check if this proxy label may create new variables.
"""
function may_create(proxy::P) where {P <: ProxyLabelInterface}
    throw(GraphPPLInterfaceNotImplemented(may_create, P, ProxyLabelInterface))
end

"""
    set_may_create!(proxy::P, flag) where {P<:ProxyLabelInterface}

Set whether this proxy label may create new variables.
"""
function set_may_create!(proxy::P, flag) where {P <: ProxyLabelInterface}
    throw(GraphPPLInterfaceNotImplemented(set_may_create!, P, ProxyLabelInterface))
end

"""
    unroll(proxy::P) where {P<:ProxyLabelInterface}

Resolve the proxy to the actual object it represents.
"""
function unroll(proxy::P) where {P <: ProxyLabelInterface}
    throw(GraphPPLInterfaceNotImplemented(unroll, P, ProxyLabelInterface))
end

"""
    create_proxy_label(name::Symbol, proxied, index, may_create=false)

Create a new proxy label with the given properties.
"""
function create_proxy_label(name::Symbol, proxied, index, may_create = false)
    throw(GraphPPLInterfaceNotImplemented(create_proxy_label, nothing, ProxyLabelInterface))
end