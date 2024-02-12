@testitem "with_plugins" begin
    import GraphPPL: ModelGenerator, PluginsCollection, AbstractPluginTraitType, getplugins, with_plugins

    struct ArbitraryPluginForModelGeneratorTestsType1 <: AbstractPluginTraitType end
    struct ArbitraryPluginForModelGeneratorTestsType2 <: AbstractPluginTraitType end

    struct ArbitraryPluginForModelGeneratorTests1 end
    struct ArbitraryPluginForModelGeneratorTests2 end

    GraphPPL.plugin_type(::ArbitraryPluginForModelGeneratorTests1) = ArbitraryPluginForModelGeneratorTestsType1()
    GraphPPL.plugin_type(::ArbitraryPluginForModelGeneratorTests2) = ArbitraryPluginForModelGeneratorTestsType2()

    @testset begin
        generator = ModelGenerator(identity, (a = 1,))

        @test isempty(getplugins(generator))
        @test getplugins(generator) === PluginsCollection()

        generator_with_plugins = @inferred(with_plugins(generator, PluginsCollection(ArbitraryPluginForModelGeneratorTests1())))

        @test !isempty(getplugins(generator_with_plugins))
        @test getplugins(generator_with_plugins) === PluginsCollection(ArbitraryPluginForModelGeneratorTests1())
    end

    @testset begin
        generator = ModelGenerator(identity, (a = 1,), PluginsCollection(ArbitraryPluginForModelGeneratorTests1()))

        @test !isempty(getplugins(generator))
        @test getplugins(generator) === PluginsCollection(ArbitraryPluginForModelGeneratorTests1())

        generator_with_more_plugins = @inferred(with_plugins(generator, PluginsCollection(ArbitraryPluginForModelGeneratorTests2())))

        @test !isempty(getplugins(generator_with_more_plugins))
        @test getplugins(generator_with_more_plugins) ===
            PluginsCollection(ArbitraryPluginForModelGeneratorTests1(), ArbitraryPluginForModelGeneratorTests2())
    end
end