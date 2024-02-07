# This file contains tests for the model creation functionality of GraphPPL
# We don't use models from the `model_zoo.jl` file because they are subject to change
# These tests are meant to be stable and not change often

@testitem "Simple model #1" begin
    using Distributions

    import GraphPPL:
        create_model, getcontext, add_toplevel_model!, factor_nodes, variable_nodes, is_constant, getproperties, as_node, as_variable

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

    a = getorcreate!(model, context, NodeCreationOptions(datavar = true), :a, nothing)
    b = getorcreate!(model, context, NodeCreationOptions(datavar = true), :b, nothing)
    c = 1.0

    add_toplevel_model!(model, simple_model_2, (a = a, b = b, c = c))

    prune!(model)

    @test length(collect(filter(as_node(Gamma), model))) === 1
    @test length(collect(filter(as_node(Normal), model))) === 1
    @test length(collect(filter(as_node(sqrt), model))) === 0 # should be compiled out, c is a constant
end

@testitem "Simple state space model" begin
    using Distributions

    import GraphPPL: create_model, add_toplevel_model!

    # Test that graph construction creates the right amount of nodes and variables in a simple state space model
    @model function state_space_model(n)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:n
            x[i] ~ Normal(x[i - 1], 1)
            y[i] ~ Normal(x[i], 1)
        end
    end
    for n in [10, 30, 50, 100, 1000]
        model = create_model()
        add_toplevel_model!(model, state_space_model, (n = n,))
        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_variable(:x), model))) == n
        @test length(collect(filter(as_variable(:y), model))) == n
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