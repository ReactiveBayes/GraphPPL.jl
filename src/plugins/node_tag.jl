"""
    NodeTagPlugin

A plugin that adds an `tag` property to the factor node. This field can be used to
find a node given its `tag` with the `GraphPPL.by_nodetag` filter.
"""
struct NodeTagPlugin end

plugin_type(::NodeTagPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    ::NodeTagPlugin,
    model::FactorGraphModelInterface,
    context::ContextInterface,
    nodedata::Union{FactorNodeDataInterface, VariableNodeDataInterface}
)
    if haskey(options, :tag)
        setextra!(nodedata, :tag, getindex(options, :tag))
    end
    return nodedata
end

struct FilterByTag <: AbstractModelFilterPredicate
    tag
end

"""
    by_nodetag(tag)

A filter predicate that can be used to find a node given its `tag` in a model.
"""
by_nodetag(tag) = FilterByTag(tag)

function apply(predicate::FilterByTag, model, something)
    return hasextra(model[something], :tag) && isequal(getextra(model[something], :tag), predicate.tag)
end
