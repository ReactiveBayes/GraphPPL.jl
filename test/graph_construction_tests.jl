# This file contains tests for the model creation functionality of GraphPPL
# We don't use models from the `model_zoo.jl` file because they are subject to change
# These tests are meant to be stable and not change often

@testitem "Simple model #1" begin
    using Distributions

    import GraphPPL:
        create_model,
        getcontext,
        add_toplevel_model!,
        factor_nodes,
        variable_nodes,
        is_constant,
        getproperties,
        as_node,
        as_variable,
        degree

    @model function simple_model_1()
        x ~ Normal(0, 1)
        y ~ Gamma(1, 1)
        z ~ Normal(x, y)
    end

    model = create_model()
    context = getcontext(model)

    add_toplevel_model!(model, simple_model_1, NamedTuple())

    flabels = collect(factor_nodes(model))
    vlabels = collect(variable_nodes(model))

    # Check factors
    @test length(flabels) === 3
    @test length(collect(filter(as_node(Normal), model))) === 2
    @test length(collect(filter(as_node(Gamma), model))) === 1

    # Check variables
    @test length(vlabels) === 7
    @test length(collect(filter(label -> !is_constant(getproperties(model[label])), vlabels))) === 3
    @test length(collect(filter(label -> is_constant(getproperties(model[label])), vlabels))) === 4
    @test length(collect(filter(as_variable(:x), model))) === 1
    @test length(collect(filter(as_variable(:y), model))) === 1
    @test length(collect(filter(as_variable(:z), model))) === 1

    @test degree(model, first(collect(filter(as_variable(:x), model)))) === 2
    @test degree(model, first(collect(filter(as_variable(:y), model)))) === 2
    @test degree(model, first(collect(filter(as_variable(:z), model)))) === 1
end

@testitem "Simple model #2" begin
    using Distributions
    using GraphPPL: create_model, getcontext, getorcreate!, add_toplevel_model!, as_node, NodeCreationOptions, prune!

    @model function simple_model_2(a, b, c)
        x ~ Gamma(α = b, θ = sqrt(c))
        a ~ Normal(μ = x, σ = 1)
    end

    model = create_model()
    context = getcontext(model)

    a = getorcreate!(model, context, NodeCreationOptions(kind = :data), :a, nothing)
    b = getorcreate!(model, context, NodeCreationOptions(kind = :data), :b, nothing)
    c = 1.0

    add_toplevel_model!(model, simple_model_2, (a = a, b = b, c = c))

    prune!(model)

    @test length(collect(filter(as_node(Gamma), model))) === 1
    @test length(collect(filter(as_node(Normal), model))) === 1
    @test length(collect(filter(as_node(sqrt), model))) === 0 # should be compiled out, c is a constant
end

@testitem "Simple model #3 with lazy data creation" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, index, getproperties, is_kind

    @model function simple_submodel_3(T, x, y, Λ)
        T ~ Normal(x + y, Λ)
    end

    @model function simple_model_3(y, Σ, n, T)
        m ~ Beta(1, 1)
        for i in 1:n, j in 1:n
            T[i, j] ~ simple_submodel_3(x = m, Λ = Σ, y = y[i])
        end
    end

    @testset for n in 5:10
        model = create_model(simple_model_3(n = n)) do model, ctx
            T = getorcreate!(model, ctx, NodeCreationOptions(kind = :data_for_T), :T, LazyIndex())
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data_for_y), :y, LazyIndex())
            Σ = getorcreate!(model, ctx, NodeCreationOptions(kind = :data_for_Σ), :Σ, LazyIndex())
            return (T = T, y = y, Σ = Σ)
        end

        @test length(collect(filter(as_node(Beta), model))) === 1
        @test length(collect(filter(as_node(Normal), model))) === n^2
        @test length(collect(filter(as_variable(:T), model))) === n^2
        @test length(collect(filter(as_variable(:Σ), model))) === 1
        @test length(collect(filter(as_variable(:y), model))) === n

        # test that options are preserved
        @test all(label -> is_kind(getproperties(model[label]), :data_for_T), collect(filter(as_variable(:T), model)))
        @test all(label -> is_kind(getproperties(model[label]), :data_for_y), collect(filter(as_variable(:y), model)))
        @test all(label -> is_kind(getproperties(model[label]), :data_for_Σ), collect(filter(as_variable(:Σ), model)))

        # test that indices are of expected shape
        Tsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:T), model)))
        Σsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:Σ), model)))
        ysindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:y), model)))

        @test allunique(Tsindices)
        @test Set(Tsindices) == Set(((i, j) for i in 1:n, j in 1:n))

        @test allunique(Σsindices)
        @test Set(Σsindices) == Set([nothing])

        @test allunique(ysindices)
        @test Set(ysindices) == Set(1:n)
    end
end

@testitem "Simple state space model" begin
    using Distributions

    import GraphPPL: create_model, add_toplevel_model!, degree

    # Test that graph construction creates the right amount of nodes and variables in a simple state space model
    @model function state_space_model(n)
        γ ~ Gamma(1, 1)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], γ)
        for i in 2:n
            x[i] ~ Normal(x[i - 1], 1)
            y[i] ~ Normal(x[i], γ)
        end
    end
    for n in [10, 30, 50, 100, 1000]
        model = create_model()
        add_toplevel_model!(model, state_space_model, (n = n,))
        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_variable(:x), model))) == n
        @test length(collect(filter(as_variable(:y), model))) == n

        @test all(v -> degree(model, v) === 3, collect(filter(as_variable(:x), model))[1:(end - 1)]) # Intermediate entries have degree `3`
        @test all(v -> degree(model, v) === 2, collect(filter(as_variable(:x), model))[end:end]) # The last entry has degree `2`

        @test all(v -> degree(model, v) === 1, filter(as_variable(:y), model)) # The data entries have degree `1`

        @test length(collect(filter(as_node(Gamma), model))) == 1
        @test length(collect(filter(as_variable(:γ), model))) == 1
        @test all(v -> degree(model, v) === n + 1, filter(as_variable(:γ), model)) # The shared variable should have degree `n + 1` (1 for the prior and `n` for the likelihoods)
    end
end

@testitem "Nested model structure" begin
    using Distributions

    import GraphPPL: create_model, add_toplevel_model!
    # Test that graph construction creates the right amount of nodes and variables in a nested model structure

    @model function gcv(κ, ω, z, x, y)
        log_σ := κ * z + ω
        y ~ Normal(x, exp(log_σ))
    end

    @model function gcv_lm(y, x_prev, x_next, z, ω, κ)
        x_next ~ gcv(x = x_prev, z = z, ω = ω, κ = κ)
        y ~ Normal(x_next, 1)
    end

    @model function hgf(y)

        # Specify priors

        ξ ~ Gamma(1, 1)
        ω_1 ~ Normal(0, 1)
        ω_2 ~ Normal(0, 1)
        κ_1 ~ Normal(0, 1)
        κ_2 ~ Normal(0, 1)
        x_1[1] ~ Normal(0, 1)
        x_2[1] ~ Normal(0, 1)
        x_3[1] ~ Normal(0, 1)

        # Specify generative model

        for i in 2:(length(y) + 1)
            x_3[i] ~ Normal(μ = x_3[i - 1], σ = ξ)
            x_2[i] ~ gcv(x = x_2[i - 1], z = x_3[i], ω = ω_2, κ = κ_2)
            x_1[i] ~ gcv_lm(x_prev = x_1[i - 1], z = x_2[i], ω = ω_1, κ = κ_1, y = y[i - 1])
        end
    end

    for n in [10, 30, 50, 100, 1000]
        model = GraphPPL.create_model()
        context = GraphPPL.getcontext(model)
        for i in 1:n
            GraphPPL.getorcreate!(model, context, :y, i)
        end
        GraphPPL.add_toplevel_model!(model, hgf, (y = GraphPPL.getorcreate!(model, context, :y, 1),))
        @test length(collect(filter(as_node(Normal), model))) == (4 * n) + 7
        @test length(collect(filter(as_node(exp), model))) == 2 * n
        @test length(collect(filter(as_node(prod), model))) == 2 * n
        @test length(collect(filter(as_node(sum), model))) == 2 * n
        @test length(collect(filter(as_node(Gamma), model))) == 1
        @test length(collect(filter(as_node(Normal) & as_context(gcv), model))) == 2 * n
        @test length(collect(filter(as_variable(:x_1), model))) == n + 1
    end
end

@testitem "Creation via `ModelGenerator`" begin
    using Distributions

    import GraphPPL:
        create_model,
        getcontext,
        add_toplevel_model!,
        factor_nodes,
        variable_nodes,
        is_constant,
        getproperties,
        as_node,
        as_variable,
        ModelGenerator,
        NodeCreationOptions,
        getorcreate!,
        Model,
        NodeLabel

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
        @test_throws MethodError create_model(generator) do model, ctx
            return (a = 1, b = 2, observation = 3)
        end
    end

    @testset begin
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
end
