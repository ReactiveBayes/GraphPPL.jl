export NodeCreatedByPlugin

"""
    NodeCreatedByPlugin

A plugin that adds a `created_by` property to the factor node. This field is used to
track the expression that created the node.
"""
mutable struct NodeCreatedByPlugin
    created_by::Expr
end

GraphPPL.plugin_type(::Type{NodeCreatedByPlugin})        = FactorNodePlugin()
GraphPPL.materialize_plugin(::Type{NodeCreatedByPlugin}) = NodeCreatedByPlugin(Expr(:line, 0))
