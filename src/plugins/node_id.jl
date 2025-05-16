"""
    NodeIdPlugin

A plugin that adds an `id` property to the factor node. This field is unique for every factor node.
"""
struct NodeIdPlugin end

plugin_type(::NodeIdPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    ::NodeIdPlugin,
    model::FactorGraphModelInterface,
    context::ContextInterface,
    nodedata::Union{FactorNodeDataInterface, VariableNodeDataInterface}
)
    setextra!(nodedata, :id, nv(model))
    return nodedata
end
