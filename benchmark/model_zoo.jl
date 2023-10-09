using GraphPPL
using Distributions

@model function gcv(κ, ω, θ, x, y)
    log_σ := κ * ω + θ
    σ := exp(log_σ)
    y ~ Normal(x, σ)
end

@model function hgf(κ, ω, θ, x_begin, depth)
    local means
    means[1] ~ gcv(κ = κ, ω = ω, θ = θ, x = x_begin)
    for i = 2:depth
        means[i] ~ gcv(κ = κ, ω = ω, θ = θ, x = means[i - 1])
    end
end

function create_hgf(n::Int)
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    κ = GraphPPL.getorcreate!(model, ctx, :κ, nothing)
    ω = GraphPPL.getorcreate!(model, ctx, :ω, nothing)
    θ = GraphPPL.getorcreate!(model, ctx, :θ, nothing)
    x_begin = GraphPPL.getorcreate!(model, ctx, :x_begin, nothing)
    GraphPPL.add_terminated_submodel!(
        model,
        ctx,
        hgf,
        (κ = κ, ω = ω, θ = θ, x_begin = x_begin, depth = n);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end

gethgfconstraints() =  @constraints begin
    q(means) = q(means[begin])..q(means[end])
    for q in gcv
        q(σ, log_σ) = q(σ)q(log_σ)
        q(x, σ, y) = q(x, y)q(σ)
    end
end

@model function long_array(μ, σ, depth)
    local x
    x[1] ~ Normal(μ, σ)
    for i in 2:depth
        x[i] ~ Normal(x[i - 1], σ)
    end
end

function create_longarray(n::Int)
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    μ = GraphPPL.getorcreate!(model, ctx, :μ, nothing)
    σ = GraphPPL.getorcreate!(model, ctx, :σ, nothing)
    GraphPPL.add_terminated_submodel!(
        model,
        ctx,
        long_array,
        (μ = μ, σ = σ, depth=n);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end

longarrayconstraints() = @constraints begin
    q(x) = q(x[begin])..q(x[end])
    q(x, σ) = q(x)q(σ)
    q(μ, σ) = q(μ)q(σ)
end