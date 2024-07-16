using BenchmarkTools
using GraphPPL
using Distributions

import GraphPPL: @model

function benchmark_model_creation()
    SUITE = BenchmarkGroup()

    SUITE["model creation"]["state space (length)"] = benchmark_state_space_model()
    SUITE["model creation"]["hierarchical (depth)"] = benchmark_hierarchical_model()
    SUITE["model creation"]["recursive (depth)"] = benchmark_recursive_model()
    SUITE["model creation"]["neural net (hidden dim size)"] = benchmark_neural_net_model()

    return SUITE
end

## State space model benchmarks

function benchmark_state_space_model()
    SUITE = BenchmarkGroup()

    for n in 10 .^ range(1, stop = 5)
        # This SUITE benchmarks how long it takes to create a state space model with length `n` and default constraints
        SUITE["default constraints", n] = @benchmarkable create_state_space_model($n) evals = 1
        # This SUITE benchmarks how long it takes to create a state space model with length `n` and mean field constraints
        SUITE["mean field constraints", n] = @benchmarkable create_state_space_model($n, constraints) evals = 1 setup = begin
            constraints = state_space_mean_field_constraints()
        end
    end

    return SUITE
end

@model function state_space_model(n)
    μ ~ Normal(0, 1)
    σ ~ Gamma(1, 1)
    x[1] ~ Normal(μ, σ)
    for i in 2:n
        x[i] ~ Normal(x[i - 1], σ)
    end
end

state_space_mean_field_constraints() = @constraints begin
    q(x) = q(x[begin]) .. q(x[end])
    q(x, σ) = q(x)q(σ)
    q(μ, σ) = q(μ)q(σ)
end

function create_state_space_model(n::Int, constraints = nothing)
    plugins = if isnothing(constraints)
        GraphPPL.PluginsCollection()
    else
        GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(constraints))
    end
    return GraphPPL.create_model(GraphPPL.with_plugins(state_space_model(n = n), plugins))
end

## Hierarchical model benchmarks

function benchmark_hierarchical_model()
    SUITE = BenchmarkGroup()

    for length in 10 .^ range(1, stop = 5)
        # This SUITE benchmarks how long it takes to create a state space model with depth `2` and length `n` and default constraints
        SUITE["default constraints", length] = @benchmarkable create_hierarchical_model($length) evals = 1
        # This SUITE benchmarks how long it takes to create a state space model with depth `2` and length `2` and mean field constraints
        SUITE["mean field constraints", length] = @benchmarkable create_hierarchical_model($length, constraints) evals = 1 setup = begin
            constraints = hierarchical_mean_field_constraints()
        end
    end

    return SUITE
end

@model function gcv(κ, ω, θ, x, y)
    log_σ := κ * ω + θ
    σ := exp(log_σ)
    y ~ Normal(x, σ)
end

@model function hgf(κ, ω, θ, x_begin, length)
    means[1] ~ gcv(κ = κ, ω = ω, θ = θ, x = x_begin)
    for i in 2:length
        means[i] ~ gcv(κ = κ, ω = ω, θ = θ, x = means[i - 1])
    end
end

hierarchical_mean_field_constraints() = @constraints begin
    q(means) = q(means[begin]) .. q(means[end])
    for q in gcv
        q(σ, log_σ) = q(σ)q(log_σ)
        q(x, σ, y) = q(x, y)q(σ)
    end
end

function create_hierarchical_model(length::Int, constraints = nothing)
    plugins = if isnothing(constraints)
        GraphPPL.PluginsCollection()
    else
        GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(constraints))
    end
    return GraphPPL.create_model(GraphPPL.with_plugins(hgf(length = length), plugins)) do model, ctx
        κ = GraphPPL.getorcreate!(model, ctx, :κ, nothing)
        ω = GraphPPL.getorcreate!(model, ctx, :ω, nothing)
        θ = GraphPPL.getorcreate!(model, ctx, :θ, nothing)
        x_begin = GraphPPL.getorcreate!(model, ctx, :x_begin, nothing)
        return (; κ = κ, ω = ω, θ = θ, x_begin = x_begin)
    end
end

## Recursive model benchmarks

function benchmark_recursive_model()
    SUITE = BenchmarkGroup()

    for length in 100 .* range(1, stop = 3)
        # This SUITE benchmarks how long it takes to create a recursive model with depth `n` and length `n` and default constraints
        SUITE["default constraints", length] = @benchmarkable create_recursive_model($length) evals = 1
        # This SUITE benchmarks how long it takes to create a recursive model with depth `n` and length `n` and mean field constraints
        SUITE["mean field constraints", length] = @benchmarkable create_recursive_model($length, $(MeanField())) evals = 1
    end

    return SUITE
end

@model function recursive_model(μ, y, depth)
    if depth == 0
        y ~ Normal(0, 1)
    else
        μ ~ Normal(y, 1)
        μ ~ recursive_model(y = y, depth = depth - 1)
    end
end

function create_recursive_model(depth::Int, constraints = nothing)
    plugins = if isnothing(constraints)
        GraphPPL.PluginsCollection()
    else
        GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(constraints))
    end
    return GraphPPL.create_model(GraphPPL.with_plugins(recursive_model(depth = depth), plugins)) do model, ctx
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        μ = GraphPPL.getorcreate!(model, ctx, :μ, nothing)
        return (; y = y, μ = μ)
    end
end

## Neural net model benchmarks

function benchmark_neural_net_model()
    SUITE = BenchmarkGroup()

    for length in 2 .^ range(2, stop = 7)
        # This SUITE benchmarks how long it takes to create a neural network model with `8` layers and hidden dimension size `n` and default constraints
        SUITE["default constraints", length] = @benchmarkable create_neural_net_model($length) evals = 1
        # This SUITE benchmarks how long it takes to create a neural network model with `8` layers and hidden dimension size `n` and mean field constraints
        # SUITE["mean field constraints", length] = @benchmarkable create_neural_net_model($length, $(MeanField())) evals = 1
    end

    return SUITE
end

function dot end
function relu end

@model function neuron(in, out)
    local w
    for i in 1:(length(in))
        w[i] ~ Normal(0.0, 1.0)
    end
    bias ~ Normal(0.0, 1.0)
    unactivated := dot(in, w) + bias
    out := relu(unactivated)
end

@model function neural_network_layer(in, out, n)
    for i in 1:n
        out[i] ~ neuron(in = in)
    end
end

@model function neural_net(in, out, h_size)
    local softin
    for i in 1:length(in)
        softin[i] ~ Normal(in[i], 1.0)
    end
    h1 ~ neural_network_layer(in = softin, n = h_size)
    h2 ~ neural_network_layer(in = h1, n = h_size)
    h3 ~ neural_network_layer(in = h2, n = h_size)
    h4 ~ neural_network_layer(in = h3, n = h_size)
    h5 ~ neural_network_layer(in = h4, n = h_size)
    h6 ~ neural_network_layer(in = h5, n = h_size)
    h7 ~ neural_network_layer(in = h6, n = h_size)
    h8 ~ neural_network_layer(in = h7, n = h_size)
    out ~ neural_network_layer(in = h8, n = 5)
end

function create_neural_net_model(n::Int, constraints = nothing)
    plugins = if isnothing(constraints)
        GraphPPL.PluginsCollection()
    else
        GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(constraints))
    end
    return GraphPPL.create_model(GraphPPL.with_plugins(neural_net(h_size = n), plugins)) do model, ctx
        in = GraphPPL.datalabel(model, ctx, GraphPPL.NodeCreationOptions(kind = :data), :in, rand(10))
        out = GraphPPL.datalabel(model, ctx, GraphPPL.NodeCreationOptions(kind = :data), :out, rand(5))
        return (; in = in, out = out)
    end
end
