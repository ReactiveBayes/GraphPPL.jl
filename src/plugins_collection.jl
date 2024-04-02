
abstract type AbstractPluginTraitType end

"""
A trait object for unknown plugins. Such plugins cannot be added to the collection, unless they implement the `plugin_type` method.
"""
struct UnknownPluginType <: AbstractPluginTraitType end

"""
Checks the type of the plugin and returns the corresponding trait object.
"""
plugin_type(::Any) = UnknownPluginType()

"""
A collection of plugins.
"""
struct PluginsCollection{T}
    collection::T

    function PluginsCollection(collection::T) where {T <: Tuple}
        if any(plugin -> plugin_type(plugin) isa UnknownPluginType, collection)
            error("The collection $(collection) contains plugins of unknown type.")
        end
        return new{T}(collection)
    end
end

# By default the collection is empty
PluginsCollection() = PluginsCollection(())
PluginsCollection(collection...) = PluginsCollection(collection)

Base.isempty(collection::PluginsCollection) = isempty(collection.collection)
Base.iterate(collection::PluginsCollection) = iterate(collection.collection)
Base.iterate(collection::PluginsCollection, state) = iterate(collection.collection, state)
Base.length(collection::PluginsCollection) = length(collection.collection)

Base.:(+)(left::PluginsCollection, right) = add_plugin(left, right)
Base.:(+)(left::PluginsCollection, right::PluginsCollection) = PluginsCollection((left.collection..., right.collection...))

"""
   add_plugin(collection::PluginsCollection, plugin)

Adds a plugin to the collection. The plugin must be of a type that is supported by the collection.
"""
add_plugin(collection::PluginsCollection, plugin) = add_plugin(collection, plugin_type(plugin), plugin)
add_plugin(collection::PluginsCollection, ::UnknownPluginType, plugin) =
    error("The plugin $(plugin) has `UnknownPluginType`. Consider implementing `plugin_type` method.")
add_plugin(collection::PluginsCollection, _, plugin) = PluginsCollection((collection.collection..., plugin))

function Base.filter(::UnknownPluginType, collection::PluginsCollection)
    error("Cannot filter the collection of plugins by `UnknownPluginType`.")
end

function Base.filter(trait::AbstractPluginTraitType, collection::PluginsCollection)
    return PluginsCollection(filter(plugin -> isequal(plugin_type(plugin), trait), collection.collection))
end

struct UnionPluginType{T, U} <: AbstractPluginTraitType
    trait1::T
    trait2::U
end

function Base.isequal(type::AbstractPluginTraitType, union::UnionPluginType)
    return isequal(type, union.trait1) || isequal(type, union.trait2)
end
