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
        a = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 1, factorized = true), :a, nothing)
        b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
        return (; a = a, b = b)
    end isa Model

    @test create_model(basic_model(a = 1, b = 2)) do model, ctx
        return (;)
    end isa Model

    @test create_model(basic_model(a = 1, b = 2)) isa Model

    # The positional arguments are not yet allowed at this point, at least print a nice error message
    @test_throws "The `basic_model` model macro does not support positional arguments" basic_model(1, 2)
    @test_throws "a = ..." basic_model(1, 2)
    @test_throws "a = ..." basic_model(1, b = 2)
    @test_throws "b = ..." basic_model(1, 2)
    @test_throws "b = ..." basic_model(a = 1, 2)
end

@testitem "Indexing in provided fixed kwargs" begin
    using Distributions

    import GraphPPL: ModelGenerator, create_model, Model, as_node, neighbors, NodeLabel, getname, is_data, is_constant, getproperties, value

    @model function basic_model(inputs)
        x ~ Beta(inputs[1], inputs[2])
        z ~ Gamma(1, 1)
        y ~ Normal(x, z)
    end

    @test basic_model() isa ModelGenerator

    for a in rand(2), b in rand(2)
        model = create_model(basic_model(inputs = [a, b]))

        betanodes = collect(filter(as_node(Beta), model))

        @test length(betanodes) === 1

        betaneighbors = neighbors(model, first(betanodes))

        @test betaneighbors[1] isa NodeLabel
        @test getname(betaneighbors[1]) === :x
        @test !is_constant(getproperties(model[betaneighbors[1]]))
        @test !is_data(getproperties(model[betaneighbors[1]]))

        @test betaneighbors[2] isa NodeLabel
        @test is_constant(getproperties(model[betaneighbors[2]]))
        @test !is_data(getproperties(model[betaneighbors[2]]))
        @test value(getproperties(model[betaneighbors[2]])) === a

        @test betaneighbors[3] isa NodeLabel
        @test is_constant(getproperties(model[betaneighbors[3]]))
        @test !is_data(getproperties(model[betaneighbors[3]]))
        @test value(getproperties(model[betaneighbors[3]])) === b
    end
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
