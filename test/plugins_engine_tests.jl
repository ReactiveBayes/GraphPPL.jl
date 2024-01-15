

@testitem "Unknown types should have unknown plygin type" begin
    import GraphPPL: plugin_type, UnknownPluginType

    struct SomeArbitraryType end

    @test plugin_type(SomeArbitraryType) isa UnknownPluginType
end

@testitem "`GraphPlugin{T}` should have the same plugin type as `T`" begin
    import GraphPPL: plugin_type, GraphPlugin, GraphGlobalPlugin, FactorNodePlugin, VariableNodePlugin

    struct SomeArbitraryTypeGlobal end
    struct SomeArbitraryTypeFactor end
    struct SomeArbitraryTypeVariable end

    GraphPPL.plugin_type(::Type{SomeArbitraryTypeGlobal}) = GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryTypeFactor}) = FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryTypeVariable}) = VariableNodePlugin()

    @test plugin_type(GraphPlugin{SomeArbitraryTypeGlobal}()) === GraphGlobalPlugin()
    @test plugin_type(GraphPlugin{SomeArbitraryTypeFactor}()) === FactorNodePlugin()
    @test plugin_type(GraphPlugin{SomeArbitraryTypeVariable}()) === VariableNodePlugin()
end

@testitem "Test plugin creation" begin
    import GraphPPL: GraphPlugin, PluginCollection, materialize_plugins

    struct SomeArbitraryPluginGlobal end
    struct SomeArbitraryPluginFactor end
    struct SomeArbitraryPluginVariable end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal}) = GraphPPL.GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginFactor}) = GraphPPL.FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginVariable}) = GraphPPL.VariableNodePlugin()

    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginGlobal}) = SomeArbitraryPluginGlobal()
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginFactor}) = SomeArbitraryPluginFactor()
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginVariable}) = SomeArbitraryPluginVariable()

    @test materialize_plugins(GraphPlugin(SomeArbitraryPluginGlobal)) == PluginCollection((SomeArbitraryPluginGlobal(),))
    @test materialize_plugins(GraphPlugin(SomeArbitraryPluginFactor)) == PluginCollection((SomeArbitraryPluginFactor(),))
    @test materialize_plugins(GraphPlugin(SomeArbitraryPluginVariable)) == PluginCollection((SomeArbitraryPluginVariable(),))

    plugin_specification = GraphPlugin(SomeArbitraryPluginGlobal) + GraphPlugin(SomeArbitraryPluginFactor) + GraphPlugin(SomeArbitraryPluginVariable)

    @test materialize_plugins(plugin_specification) == PluginCollection((SomeArbitraryPluginGlobal(), SomeArbitraryPluginFactor(), SomeArbitraryPluginVariable()))

    @test materialize_plugins(GraphPPL.GraphGlobalPlugin(), plugin_specification) == PluginCollection((SomeArbitraryPluginGlobal(),))
    @test materialize_plugins(GraphPPL.FactorNodePlugin(), plugin_specification) == PluginCollection((SomeArbitraryPluginFactor(),))
    @test materialize_plugins(GraphPPL.VariableNodePlugin(), plugin_specification) == PluginCollection((SomeArbitraryPluginVariable(),))
end

@testitem "Test that the same plugin cannot be attached twice" begin
    import GraphPPL: plugin_type, attach_plugin, PluginCollection

    struct SomeArbitraryPlugin end

    GraphPPL.plugin_type(::Type{SomeArbitraryPlugin}) = GraphGlobalPlugin()
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPlugin}) = SomeArbitraryPlugin()

    collection = PluginCollection()
    new_collection = attach_plugin(collection, SomeArbitraryPlugin)

    @test new_collection == PluginCollection((SomeArbitraryPlugin(),))
    # The second time it should as the plugin is already attached
    @test_throws ErrorException attach_plugin(new_collection, SomeArbitraryPlugin)
end

@testitem "Filter `PluginCollection` by `plugin_type`" begin
    import GraphPPL: plugin_type, GraphGlobalPlugin, FactorNodePlugin, VariableNodePlugin, UnknownPluginType, PluginCollection

    struct SomeArbitraryPluginGlobal1 end
    struct SomeArbitraryPluginGlobal2 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal1}) = GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal2}) = GraphGlobalPlugin()

    struct SomeArbitraryPluginFactor1 end
    struct SomeArbitraryPluginFactor2 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginFactor1}) = FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginFactor2}) = FactorNodePlugin()

    struct SomeArbitraryPluginVariable1 end
    struct SomeArbitraryPluginVariable2 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginVariable1}) = VariableNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginVariable2}) = VariableNodePlugin()

    @test false
end