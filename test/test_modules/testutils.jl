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

    # We use a custom backend for testing purposes, instead of using the `DefaultBackend`
    # The `TestGraphPPLBackend` is a simple backend that specifies how to handle objects from `Distributions.jl`
    # It does use the default pipeline collection for the `@model` macro
    struct TestGraphPPLBackend <: GraphPPL.AbstractBackend end

    GraphPPL.model_macro_interior_pipelines(::TestGraphPPLBackend) = GraphPPL.model_macro_interior_pipelines(GraphPPL.DefaultBackend())

    # The `TestGraphPPLBackend` redirects some of the methods to the `DefaultBackend`
    # (not all though, `TestGraphPPLBackend` implements some of them for the custom structures defined also below)
    # The `DefaultBackend` has extension rules for `Distributions.jl` types for example
    GraphPPL.NodeBehaviour(::TestGraphPPLBackend, fform) = GraphPPL.NodeBehaviour(GraphPPL.DefaultBackend(), fform)
    GraphPPL.NodeType(::TestGraphPPLBackend, fform) = GraphPPL.NodeType(GraphPPL.DefaultBackend(), fform)
    GraphPPL.aliases(::TestGraphPPLBackend, fform) = GraphPPL.aliases(GraphPPL.DefaultBackend(), fform)
    GraphPPL.interfaces(::TestGraphPPLBackend, fform, n) = GraphPPL.interfaces(GraphPPL.DefaultBackend(), fform, n)
    GraphPPL.factor_alias(::TestGraphPPLBackend, f, interfaces) = GraphPPL.factor_alias(GraphPPL.DefaultBackend(), f, interfaces)
    GraphPPL.interface_aliases(::TestGraphPPLBackend, f) = GraphPPL.interface_aliases(GraphPPL.DefaultBackend(), f)
    GraphPPL.default_parametrization(::TestGraphPPLBackend, nodetype, f, rhs) =
        GraphPPL.default_parametrization(GraphPPL.DefaultBackend(), nodetype, f, rhs)
    GraphPPL.instantiate(::Type{TestGraphPPLBackend}) = TestGraphPPLBackend()

    # Check that we can alias the `+` into `sum` and `*` into `prod`
    GraphPPL.factor_alias(::TestGraphPPLBackend, ::typeof(+), interfaces) = sum
    GraphPPL.factor_alias(::TestGraphPPLBackend, ::typeof(*), interfaces) = prod

    export @model

    # This is a special `@model` macro that should be used in tests
    macro model(model_specification)
        return esc(GraphPPL.model_macro_interior(TestGraphPPLBackend, model_specification))
    end

    export create_test_model

    function create_test_model(;
        fform = identity, plugins = GraphPPL.PluginsCollection(), backend = TestGraphPPLBackend(), source = nothing
    )
        # `identity` is not really a probabilistic model and also does not have a backend nor a source code
        # for testing purposes however it should be fine
        return GraphPPL.Model(fform, plugins, backend, source)
    end

    # Node zoo fo tests 

    export PointMass, ArbitraryNode, NormalMeanVariance, NormalMeanPrecision, GammaShapeRate, GammaShapeScale, Mixture

    struct PointMass end

    GraphPPL.prettyname(::Type{PointMass}) = "δ"

    GraphPPL.NodeBehaviour(::TestGraphPPLBackend, ::Type{PointMass}) = GraphPPL.Deterministic()

    struct ArbitraryNode end

    GraphPPL.prettyname(::Type{ArbitraryNode}) = "ArbitraryNode"

    GraphPPL.NodeBehaviour(::TestGraphPPLBackend, ::Type{ArbitraryNode}) = GraphPPL.Stochastic()

    struct NormalMeanVariance end

    GraphPPL.prettyname(::Type{NormalMeanVariance}) = "𝓝(μ, σ^2)"

    GraphPPL.NodeBehaviour(::TestGraphPPLBackend, ::Type{NormalMeanVariance}) = GraphPPL.Stochastic()

    struct NormalMeanPrecision end

    GraphPPL.prettyname(::Type{NormalMeanPrecision}) = "𝓝(μ, σ^-2)"

    GraphPPL.NodeBehaviour(::TestGraphPPLBackend, ::Type{NormalMeanPrecision}) = GraphPPL.Stochastic()

    GraphPPL.aliases(::TestGraphPPLBackend, ::Type{Normal}) = (Normal, NormalMeanVariance, NormalMeanPrecision)

    GraphPPL.interfaces(::TestGraphPPLBackend, ::Type{NormalMeanVariance}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :μ, :σ))
    GraphPPL.interfaces(::TestGraphPPLBackend, ::Type{NormalMeanPrecision}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :μ, :τ))

    GraphPPL.factor_alias(::TestGraphPPLBackend, ::Type{Normal}, ::GraphPPL.StaticInterfaces{(:μ, :σ)}) = NormalMeanVariance
    GraphPPL.factor_alias(::TestGraphPPLBackend, ::Type{Normal}, ::GraphPPL.StaticInterfaces{(:μ, :τ)}) = NormalMeanPrecision

    GraphPPL.interface_aliases(::TestGraphPPLBackend, ::Type{Normal}) = GraphPPL.StaticInterfaceAliases((
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

    GraphPPL.aliases(::TestGraphPPLBackend, ::Type{Gamma}) = (Gamma, GammaShapeRate, GammaShapeScale)

    GraphPPL.interfaces(::TestGraphPPLBackend, ::Type{GammaShapeRate}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :α, :β))
    GraphPPL.interfaces(::TestGraphPPLBackend, ::Type{GammaShapeScale}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :α, :θ))

    GraphPPL.factor_alias(::TestGraphPPLBackend, ::Type{Gamma}, ::GraphPPL.StaticInterfaces{(:α, :β)}) = GammaShapeRate
    GraphPPL.factor_alias(::TestGraphPPLBackend, ::Type{Gamma}, ::GraphPPL.StaticInterfaces{(:α, :θ)}) = GammaShapeScale

    struct Mixture end

    GraphPPL.interfaces(::TestGraphPPLBackend, ::Type{Mixture}, ::StaticInt{3}) = GraphPPL.StaticInterfaces((:out, :m, :τ))

    GraphPPL.NodeBehaviour(::TestGraphPPLBackend, ::Type{Mixture}) = GraphPPL.Stochastic()

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

    GraphPPL.default_constraints(::typeof(model_with_default_constraints)) = @constraints(
        begin
            q(a, d) = q(a)q(d)
        end
    )

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
end # TestUtils testmodule
