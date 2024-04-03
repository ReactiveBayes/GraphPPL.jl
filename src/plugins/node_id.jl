"""
    NodeIdPlugin

A plugin that adds an `id` property to the factor node. This field can be used to
find a node given its `id` with the `GraphPPL.by_nodeid` filter.
"""
struct NodeIdPlugin end

plugin_type(::NodeIdPlugin) = FactorAndVariableNodesPlugin()

function preprocess_plugin(
    ::NodeIdPlugin, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options::NodeCreationOptions
)
    if haskey(options, :id)
        setextra!(nodedata, :id, getindex(options, :id))
    end
    return label, nodedata
end

struct FilterById <: AbstractModelFilterPredicate
    id
end

"""
    by_nodeid(id)

A filter predicate that can be used to find a node given its `id` in a model.
"""
by_nodeid(id) = FilterById(id)

function apply(predicate::FilterById, model, something)
    return hasextra(model[something], :id) && isequal(getextra(model[something], :id), predicate.id)
end
