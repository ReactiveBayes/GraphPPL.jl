@testmodule TestUtils begin
    using GraphPPL
    using MacroTools
    using Static
    using Distributions

    export @test_expression_generating

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

    export @test_expression_generating_broken

    macro test_expression_generating_broken(lhs, rhs)
        return esc(:(@test_broken (prettify($lhs) == prettify($rhs))))
    end

    # We use a custom backend for testing purposes, instead of using the `DefaultStrategy`
    # The `TestGraphPPLBackend` is a simple backend that specifies how to handle objects from `Distributions.jl`
    # It does use the default pipeline collection for the `@model` macro
    struct TestGraphPPLStrategy <: GraphPPL.FactorNodeStrategy end

    GraphPPL.model_macro_interior_pipelines(::TestGraphPPLStrategy) = GraphPPL.model_macro_interior_pipelines(GraphPPL.DefaultStrategy())

    # The `TestGraphPPLBackend` redirects some of the methods to the `DefaultStrategy`
    # (not all though, `TestGraphPPLBackend` implements some of them for the custom structures defined also below)
    # The `DefaultStrategy` has extension rules for `Distributions.jl` types for example
    GraphPPL.get_node_behaviour(::TestGraphPPLStrategy, fform) = GraphPPL.get_node_behaviour(GraphPPL.DefaultStrategy(), fform)
    GraphPPL.get_node_type(::TestGraphPPLStrategy, fform) = GraphPPL.get_node_type(GraphPPL.DefaultStrategy(), fform)
    GraphPPL.get_aliases(::TestGraphPPLStrategy, fform) = GraphPPL.get_aliases(GraphPPL.DefaultStrategy(), fform)
    GraphPPL.get_interfaces(::TestGraphPPLStrategy, fform, n) = GraphPPL.get_interfaces(GraphPPL.DefaultStrategy(), fform, n)
    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, f, interfaces) = GraphPPL.get_factor_alias(GraphPPL.DefaultStrategy(), f, interfaces)
    GraphPPL.get_interface_aliases(::TestGraphPPLStrategy, f) = GraphPPL.get_interface_aliases(GraphPPL.DefaultStrategy(), f)
    GraphPPL.get_default_parametrization(::TestGraphPPLStrategy, nodetype, f, rhs) =
        GraphPPL.get_default_parametrization(GraphPPL.DefaultStrategy(), nodetype, f, rhs)
    GraphPPL.get_prettyname(::TestGraphPPLStrategy, fform) = GraphPPL.get_prettyname(GraphPPL.DefaultStrategy(), fform)
    GraphPPL.instantiate(::Type{TestGraphPPLStrategy}) = TestGraphPPLStrategy()
    GraphPPL.get_model_type(::TestGraphPPLStrategy) = GraphPPL.BipartiteModel

    # Check that we can alias the `+` into `sum` and `*` into `prod`
    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, ::typeof(+), interfaces) = sum
    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, ::typeof(*), interfaces) = prod

    export @model

    # This is a special `@model` macro that should be used in tests
    macro model(model_specification)
        return esc(GraphPPL.model_macro_interior(TestGraphPPLStrategy, model_specification))
    end

    export create_test_model

    function create_test_model(;
        fform = identity, plugins = GraphPPL.PluginsCollection(), backend = TestGraphPPLStrategy(), source = nothing
    )
        # `identity` is not really a probabilistic model and also does not have a backend nor a source code
        # for testing purposes however it should be fine
        return GraphPPL.Model(fform, plugins, backend, source)
    end

    # Node zoo fo tests 

    export PointMass, ArbitraryNode, NormalMeanVariance, NormalMeanPrecision, GammaShapeRate, GammaShapeScale, Mixture

    struct PointMass end

    GraphPPL.get_prettyname(::Type{PointMass}) = "δ"

    GraphPPL.get_node_behaviour(::TestGraphPPLStrategy, ::Type{PointMass}) = GraphPPL.Deterministic()

    struct ArbitraryNode end

    GraphPPL.get_prettyname(::Type{ArbitraryNode}) = "ArbitraryNode"

    GraphPPL.get_node_behaviour(::TestGraphPPLStrategy, ::Type{ArbitraryNode}) = GraphPPL.Stochastic()

    struct NormalMeanVariance end

    GraphPPL.get_prettyname(::Type{NormalMeanVariance}) = "𝓝(μ, σ^2)"

    GraphPPL.get_node_behaviour(::TestGraphPPLStrategy, ::Type{NormalMeanVariance}) = GraphPPL.Stochastic()

    struct NormalMeanPrecision end

    GraphPPL.get_prettyname(::Type{NormalMeanPrecision}) = "𝓝(μ, σ^-2)"

    GraphPPL.get_node_behaviour(::TestGraphPPLStrategy, ::Type{NormalMeanPrecision}) = GraphPPL.Stochastic()

    GraphPPL.get_aliases(::TestGraphPPLStrategy, ::Type{Normal}) = (Normal, NormalMeanVariance, NormalMeanPrecision)

    GraphPPL.get_interfaces(::TestGraphPPLStrategy, ::Type{NormalMeanVariance}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :μ, :σ))
    GraphPPL.get_interfaces(::TestGraphPPLStrategy, ::Type{NormalMeanPrecision}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :μ, :τ))

    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, ::Type{Normal}, ::GraphPPL.StaticInterfaces{(:μ, :σ)}) = NormalMeanVariance
    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, ::Type{Normal}, ::GraphPPL.StaticInterfaces{(:μ, :τ)}) = NormalMeanPrecision

    GraphPPL.get_interface_aliases(::TestGraphPPLStrategy, ::Type{Normal}) = GraphPPL.StaticInterfaceAliases((
        (:mean, :μ),
        (:m, :μ),
        (:variance, :σ),
        (:var, :σ),
        (:v, :σ),
        (:τ⁻¹, :σ),
        (:precision, :τ),
        (:prec, :τ),
        (:p, :τ),
        (:w, :τ),
        (:σ⁻², :τ),
        (:γ, :τ)
    ))

    struct GammaShapeRate end
    struct GammaShapeScale end

    GraphPPL.get_aliases(::TestGraphPPLStrategy, ::Type{Gamma}) = (Gamma, GammaShapeRate, GammaShapeScale)

    GraphPPL.get_interfaces(::TestGraphPPLStrategy, ::Type{GammaShapeRate}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :α, :β))
    GraphPPL.get_interfaces(::TestGraphPPLStrategy, ::Type{GammaShapeScale}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :α, :θ))

    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, ::Type{Gamma}, ::GraphPPL.StaticInterfaces{(:α, :β)}) = GammaShapeRate
    GraphPPL.get_factor_alias(::TestGraphPPLStrategy, ::Type{Gamma}, ::GraphPPL.StaticInterfaces{(:α, :θ)}) = GammaShapeScale

    struct Mixture end

    GraphPPL.get_interfaces(::TestGraphPPLStrategy, ::Type{Mixture}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :m, :τ))

    GraphPPL.get_node_behaviour(::TestGraphPPLStrategy, ::Type{Mixture}) = GraphPPL.Stochastic()

    # Model zoo for tests

    export simple_model,
        vector_model,
        tensor_model,
        anonymous_in_loop,
        node_with_only_anonymous,
        node_with_two_anonymous,
        type_arguments,
        node_with_ambiguous_anonymous,
        gcv,
        gcv_lm,
        hgf,
        prior,
        broadcastable,
        broadcaster,
        inner_inner,
        inner,
        outer,
        multidim_array,
        child_model,
        parent_model,
        model_with_default_constraints,
        contains_default_constraints,
        mixture,
        filled_matrix_model

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

    @model function filled_matrix_model()
        local x
        local y
        for i in 1:3
            for j in 1:3
                y[i, j] ~ Gamma(1, 1)
                x[i, j] ~ Normal(0, y[i, j])
            end
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

    @model function broadcaster()
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

    # GraphPPL.default_constraints(::typeof(model_with_default_constraints)) = @constraints(
    #     begin
    #         q(a, d) = q(a)q(d)
    #     end
    # )

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

    @model function filled_matrix_model()
        local x
        local y
        for i in 1:3
            for j in 1:3
                y[i, j] ~ Gamma(1, 1)
                x[i, j] ~ Normal(0, y[i, j])
            end
        end
    end

    @model function coin_toss_model()
        θ ~ Beta(1, 2)
        for i in 1:5
            y[i] ~ Bernoulli(θ)
        end
    end

    const ModelsInTheZooWithoutArguments = [
        coin_toss_model,
        simple_model,
        vector_model,
        tensor_model,
        node_with_only_anonymous,
        node_with_two_anonymous,
        node_with_ambiguous_anonymous,
        outer,
        multidim_array,
        parent_model,
        contains_default_constraints,
        mixture,
        filled_matrix_model
    ]

    export ModelsInTheZooWithoutArguments

    # Helper functions for test suite

    export create_variable_node_properties, create_factor_node_properties, add_test_variable, add_test_factor

    """
        create_variable_node_properties(name, index=nothing)

    Create a VariableNodeProperties object for testing purposes.
    """
    function create_variable_node_properties(name::Symbol, index = nothing)
        return GraphPPL.VariableNodeProperties(name = name, index = index)
    end

    """
        create_factor_node_properties(fform)

    Create a FactorNodeProperties object for testing purposes.
    """
    function create_factor_node_properties(fform)
        return GraphPPL.FactorNodeProperties(fform = fform)
    end

    """
        add_test_variable(model, name, index=nothing)

    Add a test variable to the model with the given name and optional index.
    Returns the node identifier.
    """
    function add_test_variable(model, name::Symbol, index = nothing)
        ctx = GraphPPL.getcontext(model)
        node_props = create_variable_node_properties(name, index)
        node_data = GraphPPL.NodeData(ctx, node_props)

        # Generate a node label
        node_id = if index === nothing
            GraphPPL.generate_nodelabel(name)
        else
            GraphPPL.generate_nodelabel(name, index)
        end

        # Add the node to the model
        model[node_id] = node_data

        return node_id
    end

    """
        add_test_factor(model, fform)

    Add a test factor to the model with the given functional form.
    Returns the node identifier.
    """
    function add_test_factor(model, fform)
        ctx = GraphPPL.getcontext(model)
        node_props = create_factor_node_properties(fform)
        node_data = GraphPPL.NodeData(ctx, node_props)

        # Generate a node label
        node_id = GraphPPL.generate_nodelabel(fform)

        # Add the node to the model
        model[node_id] = node_data

        return node_id
    end

    """
        get_variables(ctx::GraphPPL.Context)

    Get all variables in a context.
    """
    function get_variables(ctx::GraphPPL.Context)
        return ctx.individual_variables
    end

    """
        get_variables(ctx::GraphPPL.Context, name::Symbol)

    Get all indexed variables with the given name in a context.
    """
    function get_variables(ctx::GraphPPL.Context, name::Symbol)
        if haskey(ctx.vector_variables, name)
            return ctx.vector_variables[name]
        elseif haskey(ctx.tensor_variables, name)
            return ctx.tensor_variables[name]
        end
        return nothing
    end

    """
        has_variable(ctx::GraphPPL.Context, name::Symbol)

    Check if a context has a variable with the given name.
    """
    function has_variable(ctx::GraphPPL.Context, name::Symbol)
        return haskey(ctx.individual_variables, name)
    end

    """
        has_variable(ctx::GraphPPL.Context, name::Symbol, index)

    Check if a context has an indexed variable with the given name and index.
    """
    function has_variable(ctx::GraphPPL.Context, name::Symbol, index)
        vars = get_variables(ctx, name)
        if vars !== nothing
            if isa(index, Tuple)
                return haskey(vars, index...)
            else
                return haskey(vars, index)
            end
        end
        return false
    end

    """
        get_variable(ctx::GraphPPL.Context, name::Symbol)

    Get a variable with the given name from a context.
    """
    function get_variable(ctx::GraphPPL.Context, name::Symbol)
        if haskey(ctx.individual_variables, name)
            return ctx.individual_variables[name]
        end
        return nothing
    end

    """
        get_context_child(parent_ctx::GraphPPL.Context, factor_id)

    Get a child context for a composite factor node.
    """
    function get_context_child(parent_ctx::GraphPPL.Context, factor_id)
        if haskey(GraphPPL.children(parent_ctx), factor_id)
            return GraphPPL.children(parent_ctx)[factor_id]
        end
        return nothing
    end

    """
        has_context_child(parent_ctx::GraphPPL.Context, factor_id)

    Check if a parent context has a child context for a composite factor node.
    """
    function has_context_child(parent_ctx::GraphPPL.Context, factor_id)
        return haskey(GraphPPL.children(parent_ctx), factor_id)
    end
end

@testitem "NodeType" setup = [TestUtils] begin
    using Distributions
    import GraphPPL: NodeType, Composite, Atomic

    model = TestUtils.create_test_model()

    @test get_node_type(model, Composite) == Atomic()
    @test get_node_type(model, Atomic) == Atomic()
    @test get_node_type(model, abs) == Atomic()
    @test get_node_type(model, Normal) == Atomic()
    @test get_node_type(model, TestUtils.NormalMeanVariance) == Atomic()
    @test get_node_type(model, TestUtils.NormalMeanPrecision) == Atomic()

    # Could test all here 
    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        @test get_node_type(model, model_fn) == Composite()
    end
end

@testitem "NodeBehaviour" setup = [TestUtils] begin
    using Distributions
    import GraphPPL: get_node_behaviour, Deterministic, Stochastic

    model = TestUtils.create_test_model()

    @test get_node_behaviour(model, () -> 1) == Deterministic()
    @test get_node_behaviour(model, Matrix) == Deterministic()
    @test get_node_behaviour(model, abs) == Deterministic()
    @test get_node_behaviour(model, Normal) == Stochastic()
    @test get_node_behaviour(model, TestUtils.NormalMeanVariance) == Stochastic()
    @test get_node_behaviour(model, TestUtils.NormalMeanPrecision) == Stochastic()

    # Could test all here 
    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        @test get_node_behaviour(model, model_fn) == Stochastic()
    end
end

@testitem "interface_alias" setup = [TestUtils] begin
    using Distributions
    import GraphPPL: interface_aliases, StaticInterfaces

    model = TestUtils.create_test_model()

    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :τ)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :precision)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :precision)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :τ)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :precision)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :τ)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :p)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :p)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :p)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :prec)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :prec)))) === StaticInterfaces((:out, :μ, :τ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :prec)))) === StaticInterfaces((:out, :μ, :τ))

    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :τ)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :precision)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :τ)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :precision)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :precision)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :τ)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :p)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :p)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :p)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :prec)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :m, :prec)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :prec)))) === 0

    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :σ)))) === StaticInterfaces((:out, :μ, :σ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :variance)))) === StaticInterfaces((:out, :μ, :σ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :variance)))) === StaticInterfaces((:out, :μ, :σ))
    @test @inferred(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :σ)))) === StaticInterfaces((:out, :μ, :σ))

    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :σ)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :variance)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :mean, :σ)))) === 0
    @test @allocated(interface_aliases(model, Normal, StaticInterfaces((:out, :μ, :variance)))) === 0
end

@testitem "factor_alias" setup = [TestUtils] begin
    import GraphPPL: factor_alias, StaticInterfaces

    function abc end
    function xyz end

    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(abc), ::StaticInterfaces{(:a, :b)}) = abc
    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(abc), ::StaticInterfaces{(:x, :y)}) = xyz

    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(xyz), ::StaticInterfaces{(:a, :b)}) = abc
    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(xyz), ::StaticInterfaces{(:x, :y)}) = xyz

    model = TestUtils.create_test_model()

    @test factor_alias(model, abc, StaticInterfaces((:a, :b))) === abc
    @test factor_alias(model, abc, StaticInterfaces((:x, :y))) === xyz

    @test factor_alias(model, xyz, StaticInterfaces((:a, :b))) === abc
    @test factor_alias(model, xyz, StaticInterfaces((:x, :y))) === xyz
end

@testitem "default_parametrization" setup = [TestUtils] begin
    using Distributions
    import GraphPPL: default_parametrization, Composite, Atomic

    model = TestUtils.create_test_model()

    # Test 1: Add default arguments to Normal call
    @test default_parametrization(model, Atomic(), Normal, (0, 1)) == (μ = 0, σ = 1)

    # Test 2: Add :in to function call that has default behaviour 
    @test default_parametrization(model, Atomic(), +, (1, 2)) == (in = (1, 2),)

    # Test 3: Add :in to function call that has default behaviour with nested interfaces
    @test default_parametrization(model, Atomic(), +, ([1, 1], 2)) == (in = ([1, 1], 2),)

    @test_throws ErrorException default_parametrization(model, Composite(), TestUtils.gcv, (1, 2))
end

@testitem "getindex for StaticInterfaces" setup = [TestUtils] begin
    import GraphPPL: StaticInterfaces

    interfaces = (:a, :b, :c)
    sinterfaces = StaticInterfaces(interfaces)

    for (i, interface) in enumerate(interfaces)
        @test sinterfaces[i] === interface
    end
end

@testitem "missing_interfaces" setup = [TestUtils] begin
    using Static
    import GraphPPL: missing_interfaces, interfaces

    model = TestUtils.create_test_model()

    function abc end

    GraphPPL.interfaces(::TestUtils.TestGraphPPLBackend, ::typeof(abc), ::StaticInt{3}) = GraphPPL.StaticInterfaces((:in1, :in2, :out))

    @test missing_interfaces(model, abc, static(3), (in1 = :x, in2 = :y)) == GraphPPL.StaticInterfaces((:out,))
    @test missing_interfaces(model, abc, static(3), (out = :y,)) == GraphPPL.StaticInterfaces((:in1, :in2))
    @test missing_interfaces(model, abc, static(3), NamedTuple()) == GraphPPL.StaticInterfaces((:in1, :in2, :out))

    function xyz end

    GraphPPL.interfaces(::TestUtils.TestGraphPPLBackend, ::typeof(xyz), ::StaticInt{0}) = GraphPPL.StaticInterfaces(())
    @test missing_interfaces(model, xyz, static(0), (in1 = :x, in2 = :y)) == GraphPPL.StaticInterfaces(())

    function foo end

    GraphPPL.interfaces(::TestUtils.TestGraphPPLBackend, ::typeof(foo), ::StaticInt{2}) = GraphPPL.StaticInterfaces((:a, :b))
    @test missing_interfaces(model, foo, static(2), (a = 1, b = 2)) == GraphPPL.StaticInterfaces(())

    function bar end
    GraphPPL.interfaces(::TestUtils.TestGraphPPLBackend, ::typeof(bar), ::StaticInt{2}) = GraphPPL.StaticInterfaces((:in1, :in2, :out))
    @test missing_interfaces(model, bar, static(2), (in1 = 1, in2 = 2, out = 3, test = 4)) == GraphPPL.StaticInterfaces(())
end

@testitem "sort_interfaces" setup = [TestUtils] begin
    import GraphPPL: sort_interfaces

    model = TestUtils.create_test_model()

    # Test 1: Test that sort_interfaces sorts the interfaces in the correct order
    @test sort_interfaces(model, TestUtils.NormalMeanVariance, (μ = 1, σ = 1, out = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanVariance, (out = 1, μ = 1, σ = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanVariance, (σ = 1, out = 1, μ = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanVariance, (σ = 1, μ = 1, out = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanPrecision, (μ = 1, τ = 1, out = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanPrecision, (out = 1, μ = 1, τ = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanPrecision, (τ = 1, out = 1, μ = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(model, TestUtils.NormalMeanPrecision, (τ = 1, μ = 1, out = 1)) == (out = 1, μ = 1, τ = 1)

    @test_throws ErrorException sort_interfaces(model, TestUtils.NormalMeanVariance, (σ = 1, μ = 1, τ = 1))
end

@testitem "prepare_interfaces" setup = [TestUtils] begin
    import GraphPPL: prepare_interfaces

    model = TestUtils.create_test_model()

    @test prepare_interfaces(model, TestUtils.anonymous_in_loop, 1, (y = 1,)) == (x = 1, y = 1)
    @test prepare_interfaces(model, TestUtils.anonymous_in_loop, 1, (x = 1,)) == (y = 1, x = 1)

    @test prepare_interfaces(model, TestUtils.type_arguments, 1, (x = 1,)) == (n = 1, x = 1)
    @test prepare_interfaces(model, TestUtils.type_arguments, 1, (n = 1,)) == (x = 1, n = 1)
end
