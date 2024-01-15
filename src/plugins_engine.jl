
"""
    GraphPlugin(PluginType)

GraphPlugins are constructed as a `GraphPlugin(PluginType)` and can 
be combined with other plugins using the `+` or `|` operators.
"""
struct GraphPlugin{T} end

# Holds a collection of `GraphPlugin`'s in a form of a tuple
# We use this structure to dispatch on the `+` and `|` operators
struct GraphPlugins{T}
    specification::T
end

GraphPlugin(::Type{T}) where {T} = GraphPlugins((GraphPlugin{T}(),))

function Base.:(+)(left::GraphPlugins, right::GraphPlugins)
    return GraphPlugins((left.specification..., right.specification...))
end

function Base.:(|)(left::GraphPlugins, right::GraphPlugins)
    return GraphPlugins((left.specification..., right.specification...))
end

plugin_type(::Type) = UnknownPluginType()
plugin_type(::GraphPlugin{T}) where {T} = plugin_type(T)

abstract type AbstractPluginTraitType end

"""
A trait object for unknown plugins. Such plugins cannot be used withtin the 
graph engine, unless they implement the `plugin_type` method.
"""
struct UnknownPluginType <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for the entire graph.
"""
struct GraphGlobalPlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for factor nodes.
"""
struct FactorNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for variable nodes.
"""
struct VariableNodePlugin <: AbstractPluginTraitType end

function Base.filter(ptype::AbstractPluginTraitType, specification::GraphPlugins)
    return GraphPlugins(filter(p -> plugin_type(p) === ptype, specification.specification))
end

"""
Holds a reference to a collection of materialized plugins.
"""
struct PluginCollection{T}
    plugins::T
end

# By default the collection is empty
PluginCollection() = PluginCollection(())

function materialize_plugins(plugins::GraphPlugins)
    return materialize_plugins(PluginCollection(), plugins.specification)
end

function materialize_plugins(ptype::AbstractPluginTraitType, plugins::GraphPlugins)
    return materialize_plugins(filter(ptype, plugins))
end

# We stop if there is nothing to attach anymore§
function materialize_plugins(collection::PluginCollection, remaining::Tuple{})
    return collection
end

function materialize_plugins(collection::PluginCollection, remaining::Tuple)
    return materialize_plugins(collection, first(remaining), Base.tail(remaining))
end

function materialize_plugins(collection::PluginCollection, current::GraphPlugin{T}, remaining) where {T}
    return materialize_plugins(attach_plugin(collection, T), remaining)
end

"""
    materialize_plugin(::Type{T}) where {T}

Materializes a plugin of type `T` and returns an instance of a plugin that can be attached to a `PluginCollection`.`
"""
function materialize_plugin end

"""
    attach_plugin(plugins::PluginCollection, ::Type{T})

Attaches a plugin of type `T` to the existing collection of plugins.
Returns a new `PluginCollection`.
"""
attach_plugin(plugins::PluginCollection, ::Type{T}) where {T} = attach_plugin(plugins, materialize_plugin(T))

function attach_plugin(plugins::PluginCollection, plugin)
    # Check if the `plugins` already have the same plugin attached
    if any(p -> typeof(p) == typeof(plugin), plugins.plugins)
        error("Plugin of type $(typeof(plugin)) have already been attached to the collection $(plugins).")
    end
    return PluginCollection((plugins.plugins..., plugin))
end

"""
Applies a function `f` to a plugin of type `T` in the collection in-place. Returns the same collection.
"""
function modify_plugin!(f, collection::PluginCollection, ::Type{T}) where {T}
    return modify_plugin!(f, collection, collection.plugins, T)
end

# If the reached the end of the collection it means that the plugin is not present
function modify_plugin!(f, collection::PluginCollection, ::Tuple{}, ::Type{T}) where {T}
    error("Cannot modify a plugin of type `$(T)` in the collection $(collection). The plugin is not present.")
end

function modify_plugin!(f, collection::PluginCollection, plugins::Tuple, ::Type{T}) where {T}
    return modify_plugin!(f, collection, first(plugins), Base.tail(plugins), T)
end

# If the type of the `current` is matched with `T` we apply the function `f` to it and return the collection
function modify_plugin!(f, collection::PluginCollection, current::T, remaining, ::Type{T}) where {T}
    f(current)
    return collection
end

# If the type of the `current` is not matched with `T` we skip it and process the remaining plugins
function modify_plugin!(f, collection::PluginCollection, current, remaining, ::Type{T}) where {T}
    return modify_plugin!(f, collection, remaining, T)
end