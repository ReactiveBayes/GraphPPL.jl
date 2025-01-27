@testitem "Basic creation" begin
    using Distributions
    import GraphPPL: ModelGenerator, create_model, Model, NodeCreationOptions, getorcreate!

    include("testutils.jl")

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

@testitem "Data creation via callback" begin
    using Distributions
    import GraphPPL: ModelGenerator, create_model, Model, NodeCreationOptions, getorcreate!, NodeLabel

    include("testutils.jl")

    @model function simple_model_for_model_generator(observation, a, b)
        x ~ Beta(0, 1)
        y ~ Gamma(a, b)
        observation ~ Normal(x, y)
    end

    generator = simple_model_for_model_generator(a = 1, b = 2)

    globalobservationref = Ref{Any}(nothing) # for test

    model = create_model(generator) do model, ctx
        observation = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :observation, nothing)
        @test isnothing(globalobservationref[])
        globalobservationref[] = observation
        return (observation = observation,)
    end

    @test model isa Model
    @test !isnothing(globalobservationref[])
    @test globalobservationref[] isa NodeLabel
    @test GraphPPL.is_data(GraphPPL.getproperties(model[globalobservationref[]]))

    nnodes = collect(filter(as_node(Normal), model))

    @test length(nnodes) === 1

    outedge = first(GraphPPL.neighbors(GraphPPL.getproperties(model[nnodes[1]])))

    # Test that the observation ref is connected to the `out` edge of the `Gaussian` node
    @test outedge[1] === globalobservationref[]
    @test GraphPPL.getname(outedge[2]) === :out
end

@testitem "Indexing in provided fixed kwargs" begin
    using Distributions
    import GraphPPL: ModelGenerator, create_model, Model, as_node, neighbors, NodeLabel, getname, is_data, is_constant, getproperties, value

    include("testutils.jl")

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

@testitem "Error messages" begin
    using Distributions
    import GraphPPL: create_model, Model, ModelGenerator

    include("testutils.jl")

    @model function simple_model_for_model_generator(observation, a, b)
        x ~ Beta(0, 1)
        y ~ Gamma(a, b)
        observation ~ Normal(x, y)
    end

    @testset begin
        generator = simple_model_for_model_generator(a = 1, b = 2)

        @test generator isa ModelGenerator

        # Nonsensical return value
        @test_throws "must be a `NamedTuple`" create_model(generator) do model, ctx
            return ""
        end

        # Overlapping keys
        @test_throws "should not intersect" create_model(generator) do model, ctx
            return (a = 1,)
        end
        @test_throws "should not intersect" create_model(generator) do model, ctx
            return (b = 1,)
        end
        @test_throws "should not intersect" create_model(generator) do model, ctx
            return (a = 1, b = 2)
        end
    end

    @testset begin
        generator = simple_model_for_model_generator(c = 1)

        @test generator isa ModelGenerator

        @test_throws "Missing interface a" create_model(generator) do model, ctx
            return (b = 2, observation = 3)
        end
        @test_throws "Missing interface b" create_model(generator) do model, ctx
            return (a = 2, observation = 3)
        end
        # Too many keys, `c = 1` is extra
        @test_throws "Model simple_model_for_model_generator is not defined for 4 interfaces ((:c, :a, :b, :observation))." create_model(
            generator
        ) do model, ctx
            return (a = 1, b = 2, observation = 3)
        end
    end
end

@testitem "with_plugins" begin
    import GraphPPL: ModelGenerator, PluginsCollection, AbstractPluginTraitType, getplugins, with_plugins, @model

    struct ArbitraryPluginForModelGeneratorTestsType1 <: AbstractPluginTraitType end
    struct ArbitraryPluginForModelGeneratorTestsType2 <: AbstractPluginTraitType end

    struct ArbitraryPluginForModelGeneratorTests1 end
    struct ArbitraryPluginForModelGeneratorTests2 end

    GraphPPL.plugin_type(::ArbitraryPluginForModelGeneratorTests1) = ArbitraryPluginForModelGeneratorTestsType1()
    GraphPPL.plugin_type(::ArbitraryPluginForModelGeneratorTests2) = ArbitraryPluginForModelGeneratorTestsType2()

    @model function simple_model(a)
        y ~ Normal(a, 1)
    end

    @testset begin
        generator = ModelGenerator(simple_model, (a = 1,))

        @test isempty(getplugins(generator))
        @test getplugins(generator) === PluginsCollection()

        generator_with_plugins = @inferred(with_plugins(generator, PluginsCollection(ArbitraryPluginForModelGeneratorTests1())))

        @test !isempty(getplugins(generator_with_plugins))
        @test getplugins(generator_with_plugins) === PluginsCollection(ArbitraryPluginForModelGeneratorTests1())
    end

    @testset begin
        generator = ModelGenerator(
            simple_model, (a = 1,), PluginsCollection(ArbitraryPluginForModelGeneratorTests1()), GraphPPL.DefaultBackend()
        )

        @test !isempty(getplugins(generator))
        @test getplugins(generator) === PluginsCollection(ArbitraryPluginForModelGeneratorTests1())

        generator_with_more_plugins = @inferred(with_plugins(generator, PluginsCollection(ArbitraryPluginForModelGeneratorTests2())))

        @test !isempty(getplugins(generator_with_more_plugins))
        @test getplugins(generator_with_more_plugins) ===
            PluginsCollection(ArbitraryPluginForModelGeneratorTests1(), ArbitraryPluginForModelGeneratorTests2())
    end
end

@testitem "with_backend" begin
    import GraphPPL: ModelGenerator, DefaultBackend, with_backend, getbackend, create_model

    include("testutils.jl")

    # `GraphPPL.@model` uses the `DefaultBackend`, while `@model` from `testutils.jl` uses the `TestBackend`
    GraphPPL.@model function simple_model(a)
        y ~ Normal(a, 1)
    end

    generator = ModelGenerator(simple_model, (a = 1,))
    @test getbackend(generator) === DefaultBackend()

    model = create_model(generator)
    @test model isa GraphPPL.Model
    @test getbackend(model) === DefaultBackend()

    generator_with_a_different_backend = @inferred(with_backend(generator, TestUtils.TestGraphPPLBackend()))
    @test getbackend(generator_with_a_different_backend) === TestUtils.TestGraphPPLBackend()

    model_with_a_different_backend = create_model(generator_with_a_different_backend)
    @test model_with_a_different_backend isa GraphPPL.Model
    @test getbackend(model_with_a_different_backend) === TestUtils.TestGraphPPLBackend()
end

@testitem "source code retrieval from ModelGenerator #1" begin
    import GraphPPL: @model
    using Distributions

    @model function beta_bernoulli(y)
        θ ~ Beta(1, 1)
        for i = eachindex(y)
            y[i] ~ Bernoulli(θ)
        end
    end

    @test GraphPPL.source_code(beta_bernoulli(y = 1)) === """
    function beta_bernoulli(y)
        θ ~ Beta(1, 1)
        for i = eachindex(y)
            y[i] ~ Bernoulli(θ)
        end
    end"""
end

@testitem "source code retrieval from ModelGenerator #2" begin
    import GraphPPL: @model
    using Distributions

    # Define a model with some random variables and deterministic statements
    @model function test_model(x, y)
        z ~ Normal(x, 1)
        w := z + y
        q ~ Normal(w, 1)
    end

    # Define a second model with different structure
    @model function another_model(μ, σ)
        x ~ Normal(μ, σ)
        y := x ^ 2
        z ~ Gamma(y, 1)
    end

    # Create model instances
    model1 = test_model(x = 1, y = 2)
    model2 = another_model(μ = 0, σ = 1)

    # Get source codes
    source1 = GraphPPL.source_code(model1)
    source2 = GraphPPL.source_code(model2)

    # Expected source code (normalized whitespace)
    expected1 = """
    function test_model(x, y)
        z ~ Normal(x, 1)
        w := z + y 
        q ~ Normal(w, 1)
    end"""

    expected2 = """
    function another_model(μ, σ)
        x ~ Normal(μ, σ)
        y := x ^ 2
        z ~ Gamma(y, 1)
    end"""

    # Compare normalized strings (remove extra whitespace)
    @test replace(source1, r"\s+" => " ") == replace(expected1, r"\s+" => " ")
    @test replace(source2, r"\s+" => " ") == replace(expected2, r"\s+" => " ")

    # Verify that different models return different source code
    @test source1 != source2
end

@testitem "source code retrieval from ModelGenerator #3 partial kwargs" begin
    import GraphPPL: @model
    using Distributions

    @model function beta_bernoulli(y)
        θ ~ Beta(1, 1)
        for i = eachindex(y)
            y[i] ~ Bernoulli(θ)
        end
    end

    @test GraphPPL.source_code(beta_bernoulli(), [ :y ]) === """
    function beta_bernoulli(y)
        θ ~ Beta(1, 1)
        for i = eachindex(y)
            y[i] ~ Bernoulli(θ)
        end
    end"""
end