
@testitem "Unknown types should have unknown plygin type" begin
    import GraphPPL: plugin_type, UnknownPluginType

    struct SomeArbitraryType end

    @test @inferred(plugin_type(SomeArbitraryType)) isa UnknownPluginType
end

@testitem "Test `+` and `|` oeprators" begin 
    import GraphPPL: plugin_type, GraphPlugin, GraphGlobalPlugin, FactorNodePlugin, VariableNodePlugin, PluginSpecification

    struct SomeArbitraryTypeGlobal end
    struct SomeArbitraryTypeFactor end
    struct SomeArbitraryTypeVariable end

    GraphPPL.plugin_type(::Type{SomeArbitraryTypeGlobal}) = GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryTypeFactor}) = FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryTypeVariable}) = VariableNodePlugin()

    @test @inferred(GraphPlugin(SomeArbitraryTypeGlobal) + GraphPlugin(SomeArbitraryTypeFactor) + GraphPlugin(SomeArbitraryTypeVariable)) == PluginSpecification((GraphPlugin{SomeArbitraryTypeGlobal}(), GraphPlugin{SomeArbitraryTypeFactor}(), GraphPlugin{SomeArbitraryTypeVariable}()))
    @test @inferred(GraphPlugin(SomeArbitraryTypeGlobal) | GraphPlugin(SomeArbitraryTypeFactor) | GraphPlugin(SomeArbitraryTypeVariable)) == PluginSpecification((GraphPlugin{SomeArbitraryTypeGlobal}(), GraphPlugin{SomeArbitraryTypeFactor}(), GraphPlugin{SomeArbitraryTypeVariable}()))
    @test @inferred(GraphPlugin(SomeArbitraryTypeGlobal) + GraphPlugin(SomeArbitraryTypeFactor) + GraphPlugin(SomeArbitraryTypeVariable)) == GraphPlugin(SomeArbitraryTypeGlobal) | GraphPlugin(SomeArbitraryTypeFactor) | GraphPlugin(SomeArbitraryTypeVariable)
end

@testitem "`GraphPlugin{T}` should have the same plugin type as `T`" begin
    import GraphPPL: plugin_type, GraphPlugin, GraphGlobalPlugin, FactorNodePlugin, VariableNodePlugin

    struct SomeArbitraryTypeGlobal end
    struct SomeArbitraryTypeFactor end
    struct SomeArbitraryTypeVariable end

    GraphPPL.plugin_type(::Type{SomeArbitraryTypeGlobal}) = GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryTypeFactor}) = FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryTypeVariable}) = VariableNodePlugin()

    @test @inferred(plugin_type(GraphPlugin{SomeArbitraryTypeGlobal}())) === GraphGlobalPlugin()
    @test @inferred(plugin_type(GraphPlugin{SomeArbitraryTypeFactor}())) === FactorNodePlugin()
    @test @inferred(plugin_type(GraphPlugin{SomeArbitraryTypeVariable}())) === VariableNodePlugin()
end

@testitem "Test plugin creation" begin
    import GraphPPL: GraphPlugin, PluginCollection, materialize_plugins

    struct SomeArbitraryPluginGlobal end
    struct SomeArbitraryPluginFactor end
    struct SomeArbitraryPluginVariable end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal}) = GraphPPL.GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginFactor}) = GraphPPL.FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginVariable}) = GraphPPL.VariableNodePlugin()

    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginGlobal}, options) = (SomeArbitraryPluginGlobal(), options)
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginFactor}, options) = (SomeArbitraryPluginFactor(), options)
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginVariable}, options) = (SomeArbitraryPluginVariable(), options)

    @test @inferred(materialize_plugins(GraphPlugin(SomeArbitraryPluginGlobal), nothing)) == (PluginCollection((SomeArbitraryPluginGlobal(),)), nothing)
    @test @inferred(materialize_plugins(GraphPlugin(SomeArbitraryPluginFactor), nothing)) == (PluginCollection((SomeArbitraryPluginFactor(),)), nothing)
    @test @inferred(materialize_plugins(GraphPlugin(SomeArbitraryPluginVariable), nothing)) == (PluginCollection((SomeArbitraryPluginVariable(),)), nothing)

    plugin_specification = GraphPlugin(SomeArbitraryPluginGlobal) + GraphPlugin(SomeArbitraryPluginFactor) + GraphPlugin(SomeArbitraryPluginVariable)

    @test @inferred(materialize_plugins(plugin_specification, nothing)) == (PluginCollection((SomeArbitraryPluginGlobal(), SomeArbitraryPluginFactor(), SomeArbitraryPluginVariable())), nothing)
    @test @inferred(materialize_plugins(GraphPPL.GraphGlobalPlugin(), plugin_specification, nothing)) == (PluginCollection((SomeArbitraryPluginGlobal(),)), nothing)
    @test @inferred(materialize_plugins(GraphPPL.FactorNodePlugin(), plugin_specification, nothing)) == (PluginCollection((SomeArbitraryPluginFactor(),)), nothing)
    @test @inferred(materialize_plugins(GraphPPL.VariableNodePlugin(), plugin_specification, nothing)) == (PluginCollection((SomeArbitraryPluginVariable(),)), nothing)
end

@testitem "Test that the same plugin cannot be attached twice" begin
    import GraphPPL: plugin_type, materialize_plugins, PluginCollection

    struct SomeArbitraryPlugin end

    GraphPPL.plugin_type(::Type{SomeArbitraryPlugin}) = GraphGlobalPlugin()
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPlugin}, options) = (SomeArbitraryPlugin(), options)

    plugin_specification = GraphPlugin(SomeArbitraryPlugin) + GraphPlugin(SomeArbitraryPlugin)

    @test @inferred(materialize_plugins(GraphPlugin(SomeArbitraryPlugin), nothing)) == (PluginCollection((SomeArbitraryPlugin(),)), nothing)
    @test_throws ErrorException materialize_plugins(GraphPlugin(SomeArbitraryPlugin) + GraphPlugin(SomeArbitraryPlugin), nothing)
end

@testitem "Filter `PluginCollection` by `plugin_type`" begin
    import GraphPPL: plugin_type, GraphGlobalPlugin, FactorNodePlugin, VariableNodePlugin, UnknownPluginType, PluginCollection, materialize_plugins, getplugin

    struct SomeArbitraryPluginGlobal1 end
    struct SomeArbitraryPluginGlobal2 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal1}) = GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal2}) = GraphGlobalPlugin()

    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginGlobal1}, options) = (SomeArbitraryPluginGlobal1(), options)
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginGlobal2}, options) = (SomeArbitraryPluginGlobal2(), options)

    struct SomeArbitraryPluginFactor1 end
    struct SomeArbitraryPluginFactor2 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginFactor1}) = FactorNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginFactor2}) = FactorNodePlugin()

    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginFactor1}, options) = (SomeArbitraryPluginFactor1(), options)
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginFactor2}, options) = (SomeArbitraryPluginFactor2(), options)

    struct SomeArbitraryPluginVariable1 end
    struct SomeArbitraryPluginVariable2 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginVariable1}) = VariableNodePlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginVariable2}) = VariableNodePlugin()

    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginVariable1}, options) = (SomeArbitraryPluginVariable1(), options)
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginVariable2}, options) = (SomeArbitraryPluginVariable2(), options)

    specification =
        GraphPlugin(SomeArbitraryPluginGlobal1) +
        GraphPlugin(SomeArbitraryPluginGlobal2) +
        GraphPlugin(SomeArbitraryPluginFactor1) +
        GraphPlugin(SomeArbitraryPluginFactor2) +
        GraphPlugin(SomeArbitraryPluginVariable1) +
        GraphPlugin(SomeArbitraryPluginVariable2)

    collection, options = materialize_plugins(specification, nothing)

    @test @inferred(getplugin(collection, SomeArbitraryPluginGlobal1)) isa SomeArbitraryPluginGlobal1
    @test @inferred(getplugin(collection, SomeArbitraryPluginGlobal2)) isa SomeArbitraryPluginGlobal2
    @test @inferred(getplugin(collection, SomeArbitraryPluginFactor1)) isa SomeArbitraryPluginFactor1
    @test @inferred(getplugin(collection, SomeArbitraryPluginFactor2)) isa SomeArbitraryPluginFactor2
    @test @inferred(getplugin(collection, SomeArbitraryPluginVariable1)) isa SomeArbitraryPluginVariable1
    @test @inferred(getplugin(collection, SomeArbitraryPluginVariable2)) isa SomeArbitraryPluginVariable2
end

@testitem "Get and modify a particular plugin instance within the collection" begin
    import GraphPPL: GraphGlobalPlugin, GraphPlugin, materialize_plugins, is_plugin_present, getplugin, modify_plugin!

    mutable struct SomeArbitraryPluginGlobal1
        field::Int
    end

    mutable struct SomeArbitraryPluginGlobal2
        field::Float64
    end

    # We don't include this plugin in the specification
    # to test that the `modify_plugin!` throws an error
    struct SomeArbitraryPluginGlobal3 end

    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal1}) = GraphGlobalPlugin()
    GraphPPL.plugin_type(::Type{SomeArbitraryPluginGlobal2}) = GraphGlobalPlugin()

    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginGlobal1}, options) = (SomeArbitraryPluginGlobal1(0), options)
    GraphPPL.materialize_plugin(::Type{SomeArbitraryPluginGlobal2}, options) = (SomeArbitraryPluginGlobal2(0.0), options)

    specification = GraphPlugin(SomeArbitraryPluginGlobal1) | GraphPlugin(SomeArbitraryPluginGlobal2)
    collection, options = materialize_plugins(specification, nothing)

    @test @inferred(is_plugin_present(collection, SomeArbitraryPluginGlobal1))
    @test @inferred(is_plugin_present(collection, SomeArbitraryPluginGlobal2))
    @test @inferred(!is_plugin_present(collection, SomeArbitraryPluginGlobal3))

    plugin1 = @inferred(getplugin(collection, SomeArbitraryPluginGlobal1))
    plugin2 = @inferred(getplugin(collection, SomeArbitraryPluginGlobal2))

    @test plugin1 isa SomeArbitraryPluginGlobal1
    @test plugin2 isa SomeArbitraryPluginGlobal2

    @test_throws ErrorException getplugin(collection, SomeArbitraryPluginGlobal3)
    @test getplugin(collection, SomeArbitraryPluginGlobal3, Val(false)) === GraphPPL.MissingPlugin()

    @test plugin1.field === 0
    @test plugin2.field === 0.0

    for value in 1:10
        @inferred(modify_plugin!(plugin -> plugin.field = value, collection, SomeArbitraryPluginGlobal1)) === collection
        @test plugin1.field === value
        @test plugin2.field === 0.0
    end

    for value in float.(1:10)
        @inferred(modify_plugin!(plugin -> plugin.field = value, collection, SomeArbitraryPluginGlobal2)) === collection
        @test plugin1.field === 10 # the last value in the previous test was 10
        @test plugin2.field === value
    end

    @test_throws ErrorException modify_plugin!(collection, SomeArbitraryPluginGlobal3) do plugin
        nothing
    end

    @test collection === @inferred(modify_plugin!(plugin -> nothing, collection, SomeArbitraryPluginGlobal3, Val(false)))
end