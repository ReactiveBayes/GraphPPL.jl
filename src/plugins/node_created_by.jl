export NodeCreatedByPlugin

"""
    NodeCreatedByPlugin

A plugin that adds a `created_by` property to the factor node. This field is used to
track the expression that created the node.
"""
struct NodeCreatedByPlugin
    created_by::Expr
end

const EmptyCreatedBy = Expr(:line, 0)

GraphPPL.plugin_type(::Type{NodeCreatedByPlugin}) = FactorNodePlugin()

function GraphPPL.materialize_plugin(::Type{NodeCreatedByPlugin}, options) 
    created_by = get(options, :created_by, EmptyCreatedBy)
    return materialize_plugin(NodeCreatedByPlugin, created_by, options)
end

function GraphPPL.materialize_plugin(::Type{NodeCreatedByPlugin}, created_by::Expr, options)
    return NodeCreatedByPlugin(created_by), withoutopts(options, Val((:created_by, )))
end

function GraphPPL.materialize_plugin(::Type{NodeCreatedByPlugin}, created_by::F, options) where { F }
    return NodeCreatedByPlugin(created_by()), withoutopts(options, Val((:created_by, )))
end