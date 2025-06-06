"""
A collection of plugins.
"""
struct PluginsCollection{T}
    collection::T

    function PluginsCollection(collection::T) where {T <: Tuple}
        return new{T}(collection)
    end
end

# By default the collection is empty
PluginsCollection() = PluginsCollection(())
PluginsCollection(collection...) = PluginsCollection(collection)

Base.isempty(collection::PluginsCollection) = isempty(collection.collection)
Base.iterate(collection::PluginsCollection) = iterate(collection.collection)
Base.iterate(collection::PluginsCollection, state) = iterate(collection.collection, state)
Base.length(collection::PluginsCollection) = length(collection.collection)

Base.:(+)(left::PluginsCollection, right) = add_plugin(left, right)
Base.:(+)(left::PluginsCollection, right::PluginsCollection) = PluginsCollection((left.collection..., right.collection...))

"""
   add_plugin(collection::PluginsCollection, plugin)

Adds a plugin to the collection.
"""
add_plugin(collection::PluginsCollection, plugin) = PluginsCollection((collection.collection..., plugin))

function preprocess_factor_node_plugins(
    model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface, options::FactorNodeCreationOptions
)
    return foldl(get_plugins(model); init = nodedata) do plugin, nodedata
        if is_factor_plugin(plugin)
            nodedata = preprocess_plugin(plugin, model, context, node_data, options)::typeof(node_data)
        else
            return nodedata
        end
    end
    return node_data
end

function preprocess_variable_node_plugins(model::FactorGraphModelInterface, context::ContextInterface, nodedata::VariableNodeDataInterface)
    return foldl(get_plugins(model); init = nodedata) do plugin, nodedata
        if is_variable_plugin(plugin)
            nodedata = preprocess_plugin(plugin, model, context, node_data)::typeof(node_data)
        else
            return nodedata
        end
    end
    return node_data
end

function preprocess_edge_plugins(model::FactorGraphModelInterface, edgedata::EdgeDataInterface)
    return foldl(get_plugins(model); init = edgedata) do plugin, edgedata
        if is_edge_plugin(plugin)
            edgedata = preprocess_plugin(plugin, model, edgedata)::typeof(edgedata)
        else
            return edgedata
        end
    end
    return edgedata
end