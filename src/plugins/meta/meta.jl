include("meta_engine.jl")
include("meta_macro.jl")

"""
    MetaPlugin(meta)

A plugin that adds a meta information to the factor nodes of the model.
"""
struct MetaPlugin{M}
    meta::M
end

const EmptyMeta = @meta begin end

MetaPlugin() = MetaPlugin(EmptyMeta)
MetaPlugin(::Nothing) = MetaPlugin(EmptyMeta)

GraphPPL.plugin_type(::MetaPlugin) = FactorNodePlugin()

function preprocess_plugin(
    plugin::MetaPlugin, model::Model, context::Context, label::NodeLabel, nodedata::NodeData, options::NodeCreationOptions
)
    preprocess_meta_plugin!(plugin, nodedata, getproperties(nodedata), options)
    return label, nodedata
end

function preprocess_meta_plugin!(::MetaPlugin, nodedata::NodeData, nodeproperties::FactorNodeProperties, options::NodeCreationOptions)
    if haskey(options, :meta)
        setextra!(nodedata, :meta, options[:meta])
    end
    return nothing
end

function preprocess_meta_plugin!(
    plugin::MetaPlugin, nodedata::NodeData, nodeproperties::VariableNodeProperties, options::NodeCreationOptions
)
    return nothing
end

function postprocess_plugin(plugin::MetaPlugin, model::Model)
    apply_meta!(model, plugin.meta)
    return nothing
end
