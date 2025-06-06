"""
    AbstractPlugin

Base abstract type for all plugins in the ReactiveBayes ecosystem. 
Plugins extend the functionality of the core system by providing additional features
that can be enabled or disabled as needed.
"""
abstract type PluginInterface end

"""
    is_factor_plugin(plugin::PluginInterface) 

Returns whether this plugin should be applied to factor nodes.

# Arguments
- `plugin::PluginInterface`: The plugin to check

# Returns
- `Bool`: Whether this plugin should be applied to factor nodes.
"""
function is_factor_plugin(plugin::PluginInterface)
    throw(GraphPPLInterfaceNotImplemented(is_factor_plugin, P, PluginInterface))
end

"""
    is_variable_plugin(plugin::PluginInterface) 

Returns whether this plugin should be applied to variable nodes.

# Arguments
- `plugin::PluginInterface`: The plugin to check

# Returns
- `Bool`: Whether this plugin should be applied to variable nodes.
"""
function is_variable_plugin(plugin::PluginInterface)
    throw(GraphPPLInterfaceNotImplemented(is_variable_plugin, P, PluginInterface))
end

"""
    is_edge_plugin(plugin::PluginInterface)

Returns whether this plugin should be applied to edges.

# Arguments
- `plugin::PluginInterface`: The plugin to check

# Returns
- `Bool`: Whether this plugin should be applied to edges.
"""
function is_edge_plugin(plugin::PluginInterface)
    throw(GraphPPLInterfaceNotImplemented(is_edge_plugin, P, PluginInterface))
end

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
    preprocess_plugin(plugin, model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface, options)

Call a plugin specific logic for a factor node with nodedata upon their creation.
"""
function preprocess_plugin(
    plugin::P, model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface, options
) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(preprocess_plugin, P, PluginInterface))
end

"""
    preprocess_plugin(plugin, model::FactorGraphModelInterface, edgedata::EdgeDataInterface)

Call a plugin specific logic for an edge upon its creation.
"""
function preprocess_plugin(plugin::P, model::FactorGraphModelInterface, edgedata::EdgeDataInterface) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(preprocess_plugin, P, PluginInterface))
end

"""
    postprocess_plugin(plugin::AbstractPluginTraitType, model::FactorGraphModelInterface)

Calls a plugin specific logic after the model has been created. By default does nothing.
"""
function postprocess_plugin(plugin::P, model::FactorGraphModelInterface) where {P <: PluginInterface}
    throw(GraphPPLInterfaceNotImplemented(postprocess_plugin, P, PluginInterface))
end
