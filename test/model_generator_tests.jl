@testitem "Basic creation" begin 
    using Distributions 

    import GraphPPL: ModelGenerator, create_model, Model, NodeCreationOptions, getorcreate!

    @model function basic_model(a, b)
        x ~ Normal(a, b)
        z ~ Gamma(1, 1)
        y ~ Normal(x, z)
    end

    @test basic_model() isa ModelGenerator
    @test basic_model(a = 1, b = 2) isa ModelGenerator
    
    @test create_model(basic_model()) do model, ctx 
        a = getorcreate!(model, ctx, NodeCreationOptions(constant = true, value = 1, factorized = true), :a, nothing)
        b = getorcreate!(model, ctx, NodeCreationOptions(datavar = true, factorized = true), :b, nothing)
        return (; a = a, b = b)
    end isa Model

    @test create_model(basic_model(a = 1, b = 2)) do model, ctx 
        return (; )
    end isa Model
end

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