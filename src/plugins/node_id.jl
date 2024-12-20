"""
    NodeIdPlugin

A plugin that adds an `id` property to the factor node. This field is unique for every factor node.
"""
struct NodeIdPlugin end

plugin_type(::NodeIdPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    ::NodeIdPlugin, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options::NodeCreationOptions
)
    setextra!(nodedata, :id, label.global_counter)
    return label, nodedata
end
