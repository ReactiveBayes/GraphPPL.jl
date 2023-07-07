using GraphPPL
using Distributions

@model function gcv(κ, ω, θ, x, y)
    log_σ := κ * ω + θ
    σ := exp(log_σ)
    y ~ Normal(x, σ)
end

@model function hgf(κ, ω, θ, x_begin, y_end, depth)
    local means
    means[1] ~ gcv(κ = κ, ω = ω, θ = θ, x = x_begin)
    means[depth] = y_end
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
    y_end = GraphPPL.getorcreate!(model, ctx, :y_end, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        hgf,
        y_end,
        (κ = κ, ω = ω, θ = θ, x_begin = x_begin, depth = n);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end