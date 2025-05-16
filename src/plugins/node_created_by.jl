"""
    NodeCreatedByPlugin

A plugin that adds a `created_by` property to the factor node. This field is used to
track the expression that created the node.
"""
struct NodeCreatedByPlugin end

const EmptyCreatedBy = Expr(:line, 0)

plugin_type(::NodeCreatedByPlugin) = FactorNodePlugin()

# The `created_by` field is used to track the expression that created the node.
# The field can be a lambda function in which case it must be evaluated to get the expression.
struct CreatedBy
    created_by
end

Base.show(io::IO, createdby::CreatedBy) = show_createdby(io, createdby.created_by)

show_createdby(io::IO, created_by::Expr) = print(io, created_by)
show_createdby(io::IO, created_by::Function) = show_createdby(io, created_by())

function preprocess_plugin(
    ::NodeCreatedByPlugin, model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface
)
    created_by = get(options, :created_by, EmptyCreatedBy)
    setextra!(nodedata, :created_by, CreatedBy(created_by))
    return nodedata
end
