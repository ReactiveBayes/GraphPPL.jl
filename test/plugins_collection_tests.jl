@testitem "Unknown types should have unknown plugin type" begin
    import GraphPPL: plugin_type, UnknownPluginType

    struct SomeArbitraryType end

    @test @inferred(plugin_type(SomeArbitraryType())) === UnknownPluginType()
end

@testitem "PluginsCollection" begin
    import GraphPPL: PluginsCollection, AbstractPluginTraitType, plugin_type, UnknownPluginType

    @test isempty(PluginsCollection())

    struct APluginOfUnknownType end

    # It should not be possible to add a plugin of unknown type
    @test plugin_type(APluginOfUnknownType()) === UnknownPluginType()
    @test_throws ErrorException PluginsCollection((APluginOfUnknownType(),))

    struct ArbutraryPluginType <: AbstractPluginTraitType end

    struct APluginOfArbitraryPluginType end

    GraphPPL.plugin_type(::APluginOfArbitraryPluginType) = ArbutraryPluginType()

    @test !isempty(@inferred(PluginsCollection((APluginOfArbitraryPluginType(),))))

    struct APluginOfArbitraryPluginType1 end
    struct APluginOfArbitraryPluginType2 end

    GraphPPL.plugin_type(::APluginOfArbitraryPluginType1) = ArbutraryPluginType()
    GraphPPL.plugin_type(::APluginOfArbitraryPluginType2) = ArbutraryPluginType()

    @test @inferred(PluginsCollection() + APluginOfArbitraryPluginType1() + APluginOfArbitraryPluginType2()) ===
        PluginsCollection((APluginOfArbitraryPluginType1(), APluginOfArbitraryPluginType2()))
    @test @inferred(PluginsCollection(APluginOfArbitraryPluginType1(), APluginOfArbitraryPluginType2())) ===
        PluginsCollection((APluginOfArbitraryPluginType1(), APluginOfArbitraryPluginType2()))
    @test @inferred(PluginsCollection(APluginOfArbitraryPluginType1())) === PluginsCollection((APluginOfArbitraryPluginType1(),))
    @test @inferred(PluginsCollection(APluginOfArbitraryPluginType2())) === PluginsCollection((APluginOfArbitraryPluginType2(),))

    @test collect(PluginsCollection((APluginOfArbitraryPluginType1(), APluginOfArbitraryPluginType2()))) ==
        [APluginOfArbitraryPluginType1(), APluginOfArbitraryPluginType2()]
    for (k, plugin) in enumerate(PluginsCollection((APluginOfArbitraryPluginType1(), APluginOfArbitraryPluginType2())))
        if k == 1
            @test plugin === APluginOfArbitraryPluginType1()
        elseif k == 2
            @test plugin === APluginOfArbitraryPluginType2()
        else
            @test false
        end
        k = k + 1
    end

    @test @inferred(
        PluginsCollection(APluginOfArbitraryPluginType1(),APluginOfArbitraryPluginType2()) +
        PluginsCollection(APluginOfArbitraryPluginType1(),APluginOfArbitraryPluginType2()) 
    ) === PluginsCollection(APluginOfArbitraryPluginType1(),APluginOfArbitraryPluginType2(), APluginOfArbitraryPluginType1(),APluginOfArbitraryPluginType2())
end

@testitem "PluginsCollection filtering and getters" begin
    import GraphPPL: PluginsCollection, AbstractPluginTraitType, plugin_type, UnknownPluginType, UnionPluginType

    struct ArbitraryPluginType1 <: AbstractPluginTraitType end
    struct ArbitraryPluginType2 <: AbstractPluginTraitType end

    struct ArbitraryPlugin1 end
    struct ArbitraryPlugin2 end

    GraphPPL.plugin_type(::ArbitraryPlugin1) = ArbitraryPluginType1()
    GraphPPL.plugin_type(::ArbitraryPlugin2) = ArbitraryPluginType2()

    collection = @inferred(PluginsCollection(ArbitraryPlugin1(), ArbitraryPlugin2()))

    @test_throws ErrorException filter(UnknownPluginType(), collection)
    @test @inferred(filter(ArbitraryPluginType1(), collection)) === PluginsCollection(ArbitraryPlugin1())
    @test @inferred(filter(ArbitraryPluginType2(), collection)) === PluginsCollection(ArbitraryPlugin2())
    @test @inferred(filter(UnionPluginType(ArbitraryPluginType1(), ArbitraryPluginType2()), collection)) ===
        PluginsCollection(ArbitraryPlugin1(), ArbitraryPlugin2())
end
