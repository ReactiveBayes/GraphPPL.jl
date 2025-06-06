@testmodule MockPluginModule begin
    using GraphPPL
    import GraphPPL:
        PluginInterface, FactorGraphModelInterface, ContextInterface, VariableNodeDataInterface, FactorNodeDataInterface, EdgeDataInterface

    struct MockPlugin <: GraphPPL.PluginInterface end

    function GraphPPL.preprocess_plugin(
        plugin::MockPlugin, model::FactorGraphModelInterface, context::ContextInterface, nodedata::VariableNodeDataInterface
    )
        GraphPPL.set_extra!(nodedata, :mock_plugin, true)
        return nodedata
    end

    function GraphPPL.preprocess_plugin(
        plugin::MockPlugin, model::FactorGraphModelInterface, context::ContextInterface, nodedata::FactorNodeDataInterface, options
    )
        GraphPPL.set_extra!(nodedata, :mock_plugin, true)
        return nodedata
    end

    function GraphPPL.preprocess_plugin(plugin::MockPlugin, model::FactorGraphModelInterface, edgedata::EdgeDataInterface)
        GraphPPL.set_extra!(edgedata, :mock_plugin, true)
        return edgedata
    end

    function GraphPPL.is_factor_plugin(plugin::MockPlugin)
        return true
    end

    function GraphPPL.is_variable_plugin(plugin::MockPlugin)
        return true
    end

    function GraphPPL.is_edge_plugin(plugin::MockPlugin)
        return true
    end
end
