
@testitem "Check that factor node plugins are uniquely recreated" setup = [TestUtils] begin
    import GraphPPL: create_model, with_plugins, getplugins, factor_nodes, PluginsCollection, setextra!, getextra

    struct AnArbitraryPluginForTestUniqeness end

    GraphPPL.plugin_type(::AnArbitraryPluginForTestUniqeness) = GraphPPL.FactorNodePlugin()

    count = Ref(0)

    function GraphPPL.preprocess_plugin(::AnArbitraryPluginForTestUniqeness, model, context, label, nodedata, options)
        setextra!(nodedata, :count, count[])
        count[] = count[] + 1
        return label, nodedata
    end

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(with_plugins(model_fn(), PluginsCollection(AnArbitraryPluginForTestUniqeness())))
        for f1 in factor_nodes(model), f2 in factor_nodes(model)
            if f1 !== f2
                @test getextra(model[f1], :count) !== getextra(model[f2], :count)
            else
                @test getextra(model[f1], :count) === getextra(model[f2], :count)
            end
        end
    end
end

@testitem "Check that plugins may change the options" setup = [TestUtils] begin
    import GraphPPL:
        NodeData,
        variable_nodes,
        getname,
        index,
        is_constant,
        getproperties,
        value,
        PluginsCollection,
        VariableNodeProperties,
        NodeCreationOptions,
        create_model,
        with_plugins

    struct AnArbitraryPluginForChangingOptions end

    GraphPPL.plugin_type(::AnArbitraryPluginForChangingOptions) = GraphPPL.VariableNodePlugin()

    function GraphPPL.preprocess_plugin(::AnArbitraryPluginForChangingOptions, model, context, label, nodedata, options)
        # Here we replace the original options entirely
        return label, NodeData(context, convert(VariableNodeProperties, :x, nothing, NodeCreationOptions(kind = :constant, value = 1.0)))
    end

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(with_plugins(model_fn(), PluginsCollection(AnArbitraryPluginForChangingOptions())))
        for v in variable_nodes(model)
            @test getname(getproperties(model[v])) === :x
            @test index(getproperties(model[v])) === nothing
            @test is_constant(getproperties(model[v])) === true
            @test value(getproperties(model[v])) === 1.0
        end
    end
end