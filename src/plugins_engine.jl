export GraphPlugin

"""
    GraphPlugin(PluginType)

GraphPlugins are constructed as a `GraphPlugin(PluginType)` and can 
be combined with other plugins using the `+` or `|` operators.
"""
struct GraphPlugin{T} end

materialize_plugin(::GraphPlugin{T}, options) where {T} = materialize_plugin(T, options)

# Holds a collection of `GraphPlugin`'s in a form of a tuple
# We use this structure to dispatch on the `+` and `|` operators
struct PluginSpecification{T}
    specification::T
end

PluginSpecification() = PluginSpecification(())

function Base.:(+)(left::PluginSpecification, right::PluginSpecification)
    return PluginSpecification((left.specification..., right.specification...))
end

function Base.:(|)(left::PluginSpecification, right::PluginSpecification)
    return PluginSpecification((left.specification..., right.specification...))
end

GraphPlugin(::Type{T}) where {T} = PluginSpecification((GraphPlugin{T}(),))

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

function Base.filter(ptype::AbstractPluginTraitType, specification::PluginSpecification)
    return PluginSpecification(filter(p -> plugin_type(p) === ptype, specification.specification))
end

"""
Holds a reference to a collection of materialized plugins.
"""
struct PluginCollection{T}
    plugins::T
end

# By default the collection is empty
PluginCollection() = PluginCollection(())

Base.isempty(collection::PluginCollection) = isempty(collection.plugins)

function materialize_plugins(ptype::AbstractPluginTraitType, plugins::PluginSpecification, options)
    return materialize_plugins(filter(ptype, plugins), options)
end

function materialize_plugins(plugins::PluginSpecification, options)
    specification = plugins.specification
    newcollection, newoptions = reduce(specification; init = ((), options)) do current_state, current_spec
        current_collection, current_options = current_state
        new_collection, new_options = GraphPPL.attach_plugin(current_collection, current_spec, current_options)
        return (new_collection, new_options)
    end
    return PluginCollection(newcollection), newoptions
end

"""
    materialize_plugin(::Type{T}, options) where {T}

Materializes a plugin of type `T` and returns an instance of a plugin that can be attached to a `PluginCollection`
and modified options.
"""
function materialize_plugin end

"""
    attach_plugin(plugins::Tuple, ::Type{T}, options)

Attaches a plugin of type `T` to the existing collection of plugins.
Returns a new collection and a new options.
"""
function attach_plugin(plugins::Tuple, ::GraphPlugin{T}, options) where {T} 
    plugin, newoptions = materialize_plugin(T, options)
    newcollection = attach_plugin_check_existing(plugins, plugin)
    return newcollection, newoptions
end

function attach_plugin_check_existing(plugins::Tuple, plugin)
    # Check if the `plugins` already have the same plugin attached
    if any(p -> typeof(p) == typeof(plugin), plugins)
        error("Plugin of type $(typeof(plugin)) have already been attached to the collection $(plugins).")
    end
    return (plugins..., plugin)
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

function getplugin(collection::PluginCollection, ::Type{T}, ::Val{throw_if_not_present}) where {T, throw_if_not_present}
    # The `throw_if_not_present` argument is compile-time constant and is used to throw an error if the plugin is not present
    index = findfirst(p -> typeof(p) === T, collection.plugins)
    if isnothing(index) && throw_if_not_present
        error("The plugin of type `$(T)` is not present in the collection $(collection).")
    elseif isnothing(index)
        return MissingPlugin()
    else
        return collection.plugins[index]
    end
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