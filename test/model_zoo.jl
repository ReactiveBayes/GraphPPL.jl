using GraphPPL
using MacroTools
using Static
using Distributions

macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end

struct PointMass end

struct ArbitraryNode end
GraphPPL.NodeBehaviour(::Type{ArbitraryNode}) = GraphPPL.Stochastic()

struct SomeMeta end

struct NormalMeanVariance end
struct NormalMeanPrecision end

GraphPPL.interfaces(::Type{NormalMeanVariance}, ::StaticInt{3}) = (:out, :μ, :σ)
GraphPPL.interfaces(::Type{NormalMeanPrecision}, ::StaticInt{3}) = (:out, :μ, :τ)
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :σ)}) = NormalMeanVariance
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :τ)}) = NormalMeanPrecision

struct GammaShapeRate end
struct GammaShapeScale end

GraphPPL.interfaces(::Type{GammaShapeRate}, ::StaticInt{3}) = (:out, :α, :β)
GraphPPL.interfaces(::Type{GammaShapeScale}, ::StaticInt{3}) = (:out, :α, :θ)
GraphPPL.factor_alias(::Type{Gamma}, ::Val{(:α, :β)}) = GammaShapeRate
GraphPPL.factor_alias(::Type{Gamma}, ::Val{(:α, :θ)}) = GammaShapeScale

function create_simple_model()
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
    y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
    out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        +,
        out,
        [x, y];
        __debug__ = false,
        __parent_options__ = NamedTuple{}(),
    )
    return model
end

function create_vector_model()
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    local x
    local y
    for i = 1:3
        x = GraphPPL.getorcreate!(model, ctx, :x, i)
        y = GraphPPL.getorcreate!(model, ctx, :y, i)
        x = GraphPPL.getorcreate!(model, ctx, :x, i + 1)
        GraphPPL.make_node!(
            model,
            ctx,
            +,
            x[i+1],
            [x[i], y[i]];
            __debug__ = false,
            __parent_options__ = nothing,
        )
    end
    out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        +,
        out,
        [x[4], y[3]];
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end

function create_tensor_model()
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    local x
    local y
    for i = 1:3
        x = GraphPPL.getorcreate!(model, ctx, :x, i, i)
        y = GraphPPL.getorcreate!(model, ctx, :y, i, i)
        x = GraphPPL.getorcreate!(model, ctx, :x, i + 1, i + 1)
        GraphPPL.make_node!(
            model,
            ctx,
            +,
            x[i+1, i+1],
            [x[i, i], y[i, i]];
            __debug__ = false,
            __parent_options__ = nothing,
        )
    end
    out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        +,
        out,
        [x[4, 4], y[3, 3]];
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end

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

    for i = 2:length(y)+1
        x_3[i] ~ Normal(μ = x_3[i-1], τ = ξ)
        x_2[i] ~ gcv(x = x_2[i-1], z = x_3[i], ω = ω_2, κ = κ_2)
        x_1[i] ~ gcv_lm(x_prev = x_1[i-1], z = x_2[i], ω = ω_1, κ = κ_1, y = y[i-1])
    end
end

@model function submodel_with_deterministic_functions_and_anonymous_variables(x, z)
    w ~ exp(sin(x))
    z := exp(w)
end

@model function second_submodel(a, b, c)
    w ~ Normal(a, b)
    c ~ Normal(w, 1)
    d := exp(c)
end

@model function prior(a)
    a ~ Normal(0, 1)
end

@model function broadcastable(μ, σ, out)
    out ~ Normal(μ, σ)
end

@model function broadcaster(out)
    local μ
    local σ
    for i = 1:10
        μ[i] ~ Normal(0, 1)
        σ[i] ~ Gamma(1, 1)
    end
    z .~ broadcastable(μ = μ, σ = σ)
    out ~ Normal(z[10], 1)
end

function create_nested_model()
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
    y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
    z = GraphPPL.getorcreate!(model, ctx, :z, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        submodel_with_deterministic_functions_and_anonymous_variables,
        z,
        (x = x,);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    GraphPPL.make_node!(
        model,
        ctx,
        submodel_with_deterministic_functions_and_anonymous_variables,
        z,
        (x = y,);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    GraphPPL.make_node!(
        model,
        ctx,
        second_submodel,
        z,
        (a = x, b = y);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        +,
        out,
        [z, y];
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end

function create_normal_model()
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
    y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
    z = GraphPPL.getorcreate!(model, ctx, :z, nothing)
    GraphPPL.make_node!(
        model,
        ctx,
        second_submodel,
        z,
        (a = x, b = y);
        __debug__ = false,
        __parent_options__ = nothing,
    )
    return model
end
