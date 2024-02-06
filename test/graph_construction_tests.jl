# This file contains tests for the model creation functionality of GraphPPL
# We don't use models from the `model_zoo.jl` file because they are subject to change
# These tests are meant to be stable and not change often

@testitem "Simple model #1" begin
    using Distributions

    import GraphPPL: create_model, getcontext, add_toplevel_model!, factor_nodes, variable_nodes, is_constant, getproperties, as_node, as_variable

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
        a ~ Normal(μ = x, τ = 1)
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