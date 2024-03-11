using GraphPPL
using MacroTools
using Static
using Distributions

macro test_expression_generating(lhs, rhs)
    test_expr_gen = gensym(:text_expr_gen)
    return esc(
        quote
            $test_expr_gen = (prettify($lhs) == prettify($rhs))
            if !$test_expr_gen
                println("Expressions do not match: ")
                println("lhs: ", prettify($lhs))
                println("rhs: ", prettify($rhs))
            end
            @test (prettify($lhs) == prettify($rhs))
        end
    )
end

macro test_expression_generating_broken(lhs, rhs)
    return esc(:(@test_broken (prettify($lhs) == prettify($rhs))))
end

struct PointMass end

struct ArbitraryNode end
GraphPPL.NodeBehaviour(::Type{ArbitraryNode}) = GraphPPL.Stochastic()

struct SomeMeta end

struct NormalMeanVariance end

GraphPPL.NodeBehaviour(::Type{NormalMeanVariance}) = GraphPPL.Stochastic()

struct NormalMeanPrecision end

GraphPPL.NodeBehaviour(::Type{NormalMeanPrecision}) = GraphPPL.Stochastic()

GraphPPL.aliases(::Type{Normal}) = (Normal, NormalMeanVariance, NormalMeanPrecision)

GraphPPL.interfaces(::Type{NormalMeanVariance}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :μ, :σ))
GraphPPL.interface_aliases(::Type{NormalMeanVariance}, ::GraphPPL.StaticInterfaces{(:mean, :variance)}) =
    GraphPPL.StaticInterfaces((:μ, :σ))
GraphPPL.interfaces(::Type{NormalMeanPrecision}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :μ, :τ))
GraphPPL.interface_aliases(::Type{NormalMeanPrecision}, ::GraphPPL.StaticInterfaces{(:out, :mean, :precision)}) =
    GraphPPL.StaticInterfaces((:out, :μ, :τ))
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :σ)}) = NormalMeanVariance
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :τ)}) = NormalMeanPrecision

struct GammaShapeRate end
struct GammaShapeScale end

GraphPPL.aliases(::Type{Gamma}) = (Gamma, GammaShapeRate, GammaShapeScale)

GraphPPL.interfaces(::Type{GammaShapeRate}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :α, :β))
GraphPPL.interfaces(::Type{GammaShapeScale}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :α, :θ))
GraphPPL.factor_alias(::Type{Gamma}, ::Val{(:α, :β)}) = GammaShapeRate
GraphPPL.factor_alias(::Type{Gamma}, ::Val{(:α, :θ)}) = GammaShapeScale

function create_terminated_model(fform; plugins = GraphPPL.PluginsCollection())
    __model__ = GraphPPL.create_model(; fform = fform, plugins = plugins)
    __context__ = GraphPPL.getcontext(__model__)
    GraphPPL.add_toplevel_model!(__model__, __context__, fform, NamedTuple())
    return __model__
end

struct Mixture end

GraphPPL.interfaces(::Type{Mixture}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :m, :τ))

GraphPPL.NodeBehaviour(::Type{Mixture}) = GraphPPL.Stochastic()

@model function simple_model()
    x ~ Normal(0, 1)
    y ~ Gamma(1, 1)
    z ~ Normal(x, y)
end

@model function vector_model()
    local x
    local y
    for i in 1:3
        x[i] ~ Normal(0, 1)
        y[i] ~ Gamma(1, 1)
        z[i] ~ Normal(x[i], y[i])
    end
end

@model function tensor_model()
    local x
    local y
    for i in 1:3
        x[i, i] ~ Normal(0, 1)
        y[i, i] ~ Gamma(1, 1)
        z[i, i] ~ Normal(x[i, i], y[i, i])
    end
end

@model function anonymous_in_loop(x, y)
    x_0 ~ Normal(μ = 0, σ = 1.0)
    x_prev = x_0
    for i in 1:length(x)
        x[i] ~ Normal(μ = x_prev + 1, σ = 1.0)
        x_prev = x[i]
    end

    y ~ Normal(μ = x[end], σ = 1.0)
end

@model function node_with_only_anonymous()
    x[1] ~ Normal(0, 1)
    y[1] ~ Normal(0, 1)
    for i in 2:10
        y[i] ~ Normal(0, 1)
        x[i] ~ Normal(y[i - 1] + 1, 1)
    end
end

@model function node_with_two_anonymous()
    x[1] ~ Normal(0, 1)
    y[1] ~ Normal(0, 1)
    for i in 2:10
        y[i] ~ Normal(0, 1)
        x[i] ~ Normal(y[i - 1] + 1, y[i] + 1)
    end
end

@model function type_arguments(n, x)
    local y
    for i in 1:n
        y[i] ~ Normal(0, 1)
        x[i] ~ Normal(y[i], 1)
    end
end

@model function node_with_ambiguous_anonymous()
    x[1] ~ Normal(0, 1)
    y[1] ~ Normal(0, 1)
    for i in 2:10
        x[i] ~ Normal(x[i - 1], 1)
        y[i] ~ Normal(x[i] + y[i - 1], 1)
    end
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

    for i in 2:(length(y) + 1)
        x_3[i] ~ Normal(μ = x_3[i - 1], τ = ξ)
        x_2[i] ~ gcv(x = x_2[i - 1], z = x_3[i], ω = ω_2, κ = κ_2)
        x_1[i] ~ gcv_lm(x_prev = x_1[i - 1], z = x_2[i], ω = ω_1, κ = κ_1, y = y[i - 1])
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
    for i in 1:10
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
    for i in 1:5
        w[i] ~ Gamma(1, 1)
    end
    y ~ inner(θ = w[2:3])
end

@model function multidim_array()
    local x
    for i in 1:3
        x[i, 1] ~ Normal(0, 1)
        for j in 2:3
            x[i, j] ~ Normal(x[i, j - 1], 1)
        end
    end
end

@model function child_model(in, out)
    σ ~ Gamma(1, 1)
    out ~ Normal(in, σ)
end

@model function parent_model()
    x[1] ~ Normal(0, 1)
    for i in 2:100
        x[i] ~ child_model(in = x[i - 1])
    end
end

@model function model_with_default_constraints(a, b, c, d)
    a := b + c
    d ~ Normal(a, 1)
end

@model function contains_default_constraints()
    a ~ Normal(0, 1)
    b ~ Normal(0, 1)
    c ~ Normal(0, 1)
    for i in 1:10
        d[i] ~ model_with_default_constraints(a = a, b = b, c = c)
    end
end

@model function mixture()
    m1 ~ Normal(0, 1)
    m2 ~ Normal(0, 1)
    m3 ~ Normal(0, 1)
    m4 ~ Normal(0, 1)
    t1 ~ Normal(0, 1)
    t2 ~ Normal(0, 1)
    t3 ~ Normal(0, 1)
    t4 ~ Normal(0, 1)
    y ~ Mixture(m = [m1, m2, m3, m4], τ = [t1, t2, t3, t4])
end

GraphPPL.default_constraints(::typeof(model_with_default_constraints)) = @constraints(
    begin
        q(a, d) = q(a)q(d)
    end
)
