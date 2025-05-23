"""
    AbstractPlugin

Base abstract type for all plugins in the ReactiveBayes ecosystem. 
Plugins extend the functionality of the core system by providing additional features
that can be enabled or disabled as needed.
"""
abstract type PluginInterface end

"""
    AbstractPluginTraitType

Base abstract type for plugin trait types that categorize plugins based on their functionality.
Plugin traits are used to filter and dispatch on specific types of plugins in the plugin collection.
"""
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
A trait object for plugins that add extra functionality for factor nodes.
"""
struct FactorNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for variable nodes.
"""
struct VariableNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for edges.
"""
struct EdgePlugin <: AbstractPluginTraitType end

"""
    preprocess_plugin(plugin, model::FactorGraphModelInterface, context::ContextInterface, nodedata::VariableNodeDataInterface)

Call a plugin specific logic for a variable node with nodedata upon their creation.
"""
function preprocess_plugin(
    plugin::P, model::FactorGraphModelInterface, context::ContextInterface, nodedata::VariableNodeDataInterface
) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(preprocess_plugin, P, PluginInterface))
end

"""
    preprocess_plugin(plugin, model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface)

Call a plugin specific logic for a factor node with nodedata upon their creation.
"""
function preprocess_plugin(
    plugin::P, model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface
) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(preprocess_plugin, P, PluginInterface))
end

"""
    preprocess_plugin(plugin, model::FactorGraphModelInterface, context::ContextInterface, edgedata::EdgeDataInterface)

Call a plugin specific logic for an edge upon its creation.
"""
function preprocess_plugin(
    plugin::P, model::FactorGraphModelInterface, context::ContextInterface, edgedata::EdgeDataInterface
) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(preprocess_plugin, P, PluginInterface))
end

"""
    postprocess_plugin(plugin::AbstractPluginTraitType, model::FactorGraphModelInterface)

Calls a plugin specific logic after the model has been created. By default does nothing.
"""
function postprocess_plugin(plugin::P, model::FactorGraphModelInterface) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(postprocess_plugin, P, PluginInterface))
end

"""
    preprocess_plugins(type::AbstractPluginTraitType, model::FactorGraphModelInterface, context::ContextInterface, nodedata, options)

Process a node through all plugins of a specific type in the model.

This function filters plugins by the given type, then applies each plugin's `preprocess_plugin` method 
to the node data in sequence. Each plugin can modify the node data.

# Arguments
- `type::AbstractPluginTraitType`: The type of plugins to filter and apply.
- `model::FactorGraphModelInterface`: The model containing the plugins.
- `context::ContextInterface`: The context in which the node exists.
- `nodedata`: The data of the node being processed.

# Returns
The potentially modified `nodedata` after all plugins have been applied.
"""
function preprocess_plugins(type::AbstractPluginTraitType, model::FactorGraphModelInterface, context::ContextInterface, nodedata)
    plugins = filter(type, getplugins(model))
    return foldl(plugins; init = nodedata) do nodedata, plugin
        return preprocess_plugin(plugin, model, context, nodedata)
    end
end