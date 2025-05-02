"""
A trait object for plugins that add extra functionality for factor nodes.
"""
struct FactorNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality for variable nodes.
"""
struct VariableNodePlugin <: AbstractPluginTraitType end

"""
A trait object for plugins that add extra functionality both for factor and variable nodes.
"""
struct FactorAndVariableNodesPlugin <: AbstractPluginTraitType end

"""
    preprocess_plugin(plugin, model, context, label, nodedata, options)

Call a plugin specific logic for a node with label and nodedata upon their creation.
"""
function preprocess_plugin end

"""
    postprocess_plugin(plugin, model)

Calls a plugin specific logic after the model has been created. By default does nothing.
"""
postprocess_plugin(plugin, model) = nothing

function preprocess_plugins(
    type::AbstractPluginTraitType, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options
)::Tuple{NodeLabel, NodeData}
    plugins = filter(type, getplugins(model))
    return foldl(plugins; init = (label, nodedata)) do (label, nodedata), plugin
        return preprocess_plugin(plugin, model, context, label, nodedata, options)::Tuple{NodeLabel, NodeData}
    end::Tuple{NodeLabel, NodeData}
end