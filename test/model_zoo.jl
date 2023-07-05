using GraphPPL
using MacroTools

macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end

struct PointMass end

struct ArbitraryNode end
GraphPPL.NodeBehaviour(::Type{ArbitraryNode}) = GraphPPL.Stochastic()

struct Normal
    μ::Number
    σ::Number
end
struct SomeMeta end

GraphPPL.NodeBehaviour(::Type{Normal}) = GraphPPL.Stochastic()
GraphPPL.interfaces(::Type{Normal}, ::Val{3}) = (:out, :μ, :σ)
GraphPPL.rhs_to_named_tuple(::GraphPPL.Atomic, ::Type{Normal}, interface_values) =
    NamedTuple{(:μ, :σ)}(interface_values)

struct NormalMeanVariance end
struct NormalMeanPrecision end

GraphPPL.interfaces(::Type{NormalMeanVariance}, ::Val{3}) = (:out, :μ, :σ)
GraphPPL.interfaces(::Type{NormalMeanPrecision}, ::Val{3}) = (:out, :μ, :τ)
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :σ)}) = NormalMeanVariance
GraphPPL.factor_alias(::Type{Normal}, ::Val{(:μ, :τ)}) = NormalMeanPrecision

struct Gamma
    α::Number
    β::Number
end

GraphPPL.NodeBehaviour(::Type{Gamma}) = GraphPPL.Stochastic()
GraphPPL.interfaces(::Type{Gamma}, ::Val{3}) = (:out, :α, :β)
GraphPPL.rhs_to_named_tuple(::GraphPPL.Atomic, ::Type{Gamma}, interface_values) =
    NamedTuple{(:α, :β)}(interface_values)

struct GammaShapeRate end
struct GammaShapeScale end

GraphPPL.interfaces(::Type{GammaShapeRate}, ::Val{3}) = (:out, :α, :β)
GraphPPL.interfaces(::Type{GammaShapeScale}, ::Val{3}) = (:out, :α, :θ)
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

GraphPPL.@model function submodel_with_deterministic_functions_and_anonymous_variables(x, z)
    w ~ exp(sin(x))
    z := exp(w)
end

GraphPPL.@model function second_submodel(a, b, c)
    w ~ Normal(a, b)
    c ~ Normal(w, 1)
    d := exp(c)
end

GraphPPL.@model function prior()
    a ~ Normal(0, 1)
    return a
end

GraphPPL.@model function broadcastable(μ, σ, out)
    out ~ Normal(μ, σ)
end

GraphPPL.@model function broadcaster(out)
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
