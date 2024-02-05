

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

"""
   add_plugin(collection::PluginCollection, plugin)

Adds a plugin to the collection. The plugin must be of a type that is supported by the collection.
"""
add_plugin(collection::PluginsCollection, plugin) = add_plugin(collection, plugin_type(plugin), plugin)
add_plugin(collection::PluginsCollection, ::UnknownPluginType, plugin) = error("The plugin $(plugin) has `UnknownPluginType`. Consider implementing `plugin_type` method.")
add_plugin(collection::PluginsCollection, _, plugin) = PluginsCollection((collection.collection..., plugin))

function Base.filter(::UnknownPluginType, collection::PluginsCollection)
    error("Cannot filter the collection of plugins by `UnknownPluginType`.")
end

function Base.filter(trait::AbstractPluginTraitType, collection::PluginsCollection)
    return PluginsCollection(filter(plugin -> plugin_type(plugin) === trait, collection.collection))
end



# # OLD STUFF BELOW

# function materialize_plugins(ptype::AbstractPluginTraitType, plugins::PluginSpecification, options)
#     return materialize_plugins(filter(ptype, plugins), options)
# end

# function materialize_plugins(plugins::PluginSpecification, options)
#     specification = plugins.specification
#     newcollection, newoptions = reduce(specification; init = ((), options)) do current_state, current_spec
#         current_collection, current_options = current_state
#         new_collection, new_options = GraphPPL.attach_plugin(current_collection, current_spec, current_options)
#         return (new_collection, new_options)
#     end
#     return PluginCollection(newcollection), newoptions
# end

# """
#     materialize_plugin(::Type{T}, options) where {T}

# Materializes a plugin of type `T` and returns an instance of a plugin that can be attached to a `PluginCollection`
# and modified options.
# """
# function materialize_plugin end

# """
#     attach_plugin(plugins::Tuple, ::Type{T}, options)

# Attaches a plugin of type `T` to the existing collection of plugins.
# Returns a new collection and a new options.
# """
# function attach_plugin(plugins::Tuple, ::GraphPlugin{T}, options) where {T} 
#     plugin, newoptions = materialize_plugin(T, options)
#     newcollection = attach_plugin_check_existing(plugins, plugin)
#     return newcollection, newoptions
# end

# function attach_plugin_check_existing(plugins::Tuple, plugin)
#     # Check if the `plugins` already have the same plugin attached
#     if any(p -> typeof(p) == typeof(plugin), plugins)
#         error("Plugin of type $(typeof(plugin)) have already been attached to the collection $(plugins).")
#     end
#     return (plugins..., plugin)
# end

# """
# An object that is returned from `getplugin` if the plugin is not present in the collection.
# """
# struct MissingPlugin end

# """
#     is_plugin_present(collection::PluginCollection, ::Type{T}) where {T}

# Tests either a plugin of type `T` is present in the collection. Returns `true` if the plugin is present and `false` otherwise.
# """
# function is_plugin_present(collection::PluginCollection, ::Type{T}) where {T}
#     return getplugin(collection, T, Val(false)) !== MissingPlugin()
# end

# """
#     getplugin(plugins::PluginCollection, ::Type{T}, [throw_if_not_present::Val{true/false}])

# Returns a plugin of type `T` from the collection. By default throws an error if the plugin of type `T` is not present in the collection.
# Use `getplugin(plugins, T, Val(false))` to suppress the error and return `MissingPlugin()` instead.
# """
# function getplugin(collection::PluginCollection, ::Type{T}) where {T}
#     return getplugin(collection, T, Val(true))
# end

# function getplugin(collection::PluginCollection, ::Type{T}, ::Val{throw_if_not_present}) where {T, throw_if_not_present}
#     # The `throw_if_not_present` argument is compile-time constant and is used to throw an error if the plugin is not present
#     index = findfirst(p -> typeof(p) === T, collection.plugins)
#     if isnothing(index) && throw_if_not_present
#         error("The plugin of type `$(T)` is not present in the collection $(collection).")
#     elseif isnothing(index)
#         return MissingPlugin()
#     else
#         return collection.plugins[index]
#     end
# end

# """
#     modify_plugin!(f, collection::PluginCollection, ::Type{T}, [throw_if_not_present::Val{true/false}])

# Applies a function `f` to a plugin of type `T` in the collection in-place. Returns the same collection.
# By default throws an error if the plugin of type `T` is not present in the collection.
# Use `modify_plugin!(f, collection, T, Val(false))` to suppress the error.
# """
# function modify_plugin!(f, collection::PluginCollection, ::Type{T}) where {T}
#     # The `throw_if_not_present` argument is compile-time constant and is used to throw an error if the plugin is not present
#     return modify_plugin!(f, collection, T, Val(true))
# end

# function modify_plugin!(f, collection::PluginCollection, ::Type{T}, throw_if_not_present) where {T}
#     plugin = getplugin(collection, T, throw_if_not_present)
#     if plugin !== MissingPlugin()
#         f(plugin)
#     end
#     return collection
# end