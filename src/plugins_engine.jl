
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
An object that is returned from `getplugin` if the plugin is not present in the collection.
"""
struct MissingPlugin end

"""
    is_plugin_present(collection::PluginCollection, ::Type{T}) where {T}

Tests either a plugin of type `T` is present in the collection. Returns `true` if the plugin is present and `false` otherwise.
"""
function is_plugin_present(collection::PluginCollection, ::Type{T}) where {T}
    return getplugin(collection, T, Val(false)) !== MissingPlugin()
end

"""
    getplugin(plugins::PluginCollection, ::Type{T}, [throw_if_not_present::Val{true/false}])

Returns a plugin of type `T` from the collection. By default throws an error if the plugin of type `T` is not present in the collection.
Use `getplugin(plugins, T, Val(false))` to suppress the error and return `MissingPlugin()` instead.
"""
function getplugin(collection::PluginCollection, ::Type{T}) where {T}
    return getplugin(collection, T, Val(true))
end

function getplugin(collection::PluginCollection, ::Type{T}, throw_if_not_present) where {T}
    # The `throw_if_not_present` argument is compile-time constant and is used to throw an error if the plugin is not present
    return getplugin(collection, collection.plugins, T, throw_if_not_present)
end

# If the reached the end of the collection it means that the plugin is not present
function getplugin(collection::PluginCollection, ::Tuple{}, ::Type{T}, ::Val{true}) where {T}
    # The `throw_if_not_present` argument is `true` thus we throw an error
    error("The plugin of type `$(T)` is not present in the collection $(collection).")
end

function getplugin(collection::PluginCollection, ::Tuple{}, ::Type{T}, ::Val{false}) where {T}
    # The `throw_if_not_present` argument is `false` thus we return `MissingPlugin`
    return MissingPlugin()
end

function getplugin(collection::PluginCollection, remaining::Tuple, ::Type{T}, throw_if_not_present) where {T}
    return getplugin(collection, first(remaining), Base.tail(remaining), T, throw_if_not_present)
end

# If the type of the `current` is matched with `T` we return it
function getplugin(collection::PluginCollection, current::T, remaining::Tuple, ::Type{T}, throw_if_not_present) where {T}
    return current
end

# If the type of the `current` is not matched with `T` we skip it and process the remaining plugins
function getplugin(collection::PluginCollection, current, remaining::Tuple, ::Type{T}, throw_if_not_present) where {T}
    return getplugin(collection, remaining, T, throw_if_not_present)
end

"""
    modify_plugin!(f, collection::PluginCollection, ::Type{T}, [throw_if_not_present::Val{true/false}])

Applies a function `f` to a plugin of type `T` in the collection in-place. Returns the same collection.
By default throws an error if the plugin of type `T` is not present in the collection.
Use `modify_plugin!(f, collection, T, Val(false))` to suppress the error.
"""
function modify_plugin!(f, collection::PluginCollection, ::Type{T}) where {T}
    # The `throw_if_not_present` argument is compile-time constant and is used to throw an error if the plugin is not present
    return modify_plugin!(f, collection, T, Val(true))
end

function modify_plugin!(f, collection::PluginCollection, ::Type{T}, throw_if_not_present) where {T}
    plugin = getplugin(collection, T, throw_if_not_present)
    if plugin !== MissingPlugin()
        f(plugin)
    end
    return collection
end