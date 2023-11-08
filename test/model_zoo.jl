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

GraphPPL.aliases(::Type{Normal}) = (Normal, NormalMeanVariance, NormalMeanPrecision)

GraphPPL.interfaces(::Type{NormalMeanVariance}, ::StaticInt{3}) = (:out, :μ, :σ)
GraphPPL.interfaces(::Type{NormalMeanPrecision}, ::StaticInt{3}) = (:out, :μ, :τ)
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :σ)}) = NormalMeanVariance
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :τ)}) = NormalMeanPrecision

struct GammaShapeRate end
struct GammaShapeScale end

GraphPPL.aliases(::Type{Gamma}) = (Gamma, GammaShapeRate, GammaShapeScale)

GraphPPL.interfaces(::Type{GammaShapeRate}, ::StaticInt{3}) = (:out, :α, :β)
GraphPPL.interfaces(::Type{GammaShapeScale}, ::StaticInt{3}) = (:out, :α, :θ)
GraphPPL.factor_alias(::Type{Gamma}, ::Val{(:α, :β)}) = GammaShapeRate
GraphPPL.factor_alias(::Type{Gamma}, ::Val{(:α, :θ)}) = GammaShapeScale

function create_terminated_model(fform)
    __model__ = GraphPPL.create_model(; fform=fform)
    __context__ = GraphPPL.getcontext(__model__)
    GraphPPL.add_terminated_submodel!(__model__, __context__, fform, NamedTuple())
    return __model__
end

@model function simple_model()
    x ~ Normal(0, 1)
    y ~ Gamma(1, 1)
    z ~ Normal(x, y)
end

@model function vector_model()
    local x
    local y
    for i = 1:3
        x[i] ~ Normal(0, 1)
        y[i] ~ Gamma(1, 1)
        z[i] ~ Normal(x[i], y[i])
    end
end

@model function tensor_model()
    local x
    local y
    for i = 1:3
        x[i, i] ~ Normal(0, 1)
        y[i, i] ~ Gamma(1, 1)
        z[i, i] ~ Normal(x[i, i], y[i, i])
    end
end

@model function anonymous_in_loop(x, y)
    x_0 ~ Normal(μ = 0, σ = 1.0)
    x_prev = x_0
    for i = 1:length(x)
        x[i] ~ Normal(μ = x_prev + 1, σ = 1.0)
        x_prev = x[i]
    end

    y ~ Normal(μ = x[end], σ = 1.0)
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


@model function inner_inner(τ, y)
    y ~ Normal(τ[1], τ[2])
end

@model function inner(θ, α)
    α ~ inner_inner(τ = θ)
end

@model function outer()
    local w
    for i = 1:5
        w[i] ~ Gamma(1, 1)
    end
    y ~ inner(θ = w[2:3])
end

@model function multidim_array()
    local x
    for i = 1:3
        x[i, 1] ~ Normal(0, 1)
        for j = 2:3
            x[i, j] ~ Normal(x[i, j-1], 1)
        end
    end
end
