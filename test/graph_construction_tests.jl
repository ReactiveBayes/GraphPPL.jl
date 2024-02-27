# This file contains tests for the model creation functionality of GraphPPL
# We don't use models from the `model_zoo.jl` file because they are subject to change
# These tests are meant to be stable and not change often

@testitem "Simple model 1" begin
    using Distributions

    import GraphPPL:
        create_model,
        getcontext,
        add_toplevel_model!,
        factor_nodes,
        variable_nodes,
        is_constant,
        getproperties,
        as_node,
        as_variable,
        degree

    @model function simple_model_1()
        x ~ Normal(0, 1)
        y ~ Gamma(1, 1)
        z ~ Normal(x, y)
    end

    model = create_model(simple_model_1())

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

    @test degree(model, first(collect(filter(as_variable(:x), model)))) === 2
    @test degree(model, first(collect(filter(as_variable(:y), model)))) === 2
    @test degree(model, first(collect(filter(as_variable(:z), model)))) === 1
end

@testitem "Simple model 2" begin
    using Distributions
    using GraphPPL: create_model, getcontext, getorcreate!, add_toplevel_model!, as_node, NodeCreationOptions, prune!

    @model function simple_model_2(a, b, c)
        x ~ Gamma(α = b, θ = sqrt(c))
        a ~ Normal(μ = x, σ = 1)
    end

    model = create_model(simple_model_2()) do model, context
        a = getorcreate!(model, context, NodeCreationOptions(kind = :data), :a, nothing)
        b = getorcreate!(model, context, NodeCreationOptions(kind = :data), :b, nothing)
        c = 1.0
        return (a = a, b = b, c = c)
    end

    @test length(collect(filter(as_node(Gamma), model))) === 1
    @test length(collect(filter(as_node(Normal), model))) === 1
    @test length(collect(filter(as_node(sqrt), model))) === 0 # should be compiled out, c is a constant
end

@testitem "Simple model but wrong indexing into a single random variable" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, NodeCreationOptions

    @model function simple_model_with_wrong_indexing(y)
        x ~ MvNormal([0.0, 0.0], [1.0 0.0; 0.0 1.0])
        y ~ Beta(x[1], x[2])
    end

    # We may want to support it in the future, but for now we at least show a clear error message
    @test_throws "Indexing a single node label `x` with an index `[1]` is not allowed." create_model(
        simple_model_with_wrong_indexing()
    ) do model, context
        return (y = getorcreate!(model, context, NodeCreationOptions(kind = :data), :y, nothing),)
    end
end

@testitem "Simple model with lazy data (number) creation" begin
    using Distributions

    using GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, is_data, is_constant, is_random, getproperties

    @model function simple_model_3(a, b, c, d)
        x ~ Beta(a, b)
        y ~ Gamma(c, d)
        z ~ Normal(x, y)
    end

    model = create_model(simple_model_3()) do model, context
        a = getorcreate!(model, context, NodeCreationOptions(kind = :data), :a, LazyIndex(1))
        b = getorcreate!(model, context, NodeCreationOptions(kind = :data), :b, LazyIndex(2.0))
        c = getorcreate!(model, context, NodeCreationOptions(kind = :data), :c, LazyIndex(π))
        d = getorcreate!(model, context, NodeCreationOptions(kind = :data), :d, LazyIndex(missing))
        return (a = a, b = b, c = c, d = d)
    end

    @test length(collect(filter(as_node(Beta), model))) === 1
    @test length(collect(filter(as_node(Gamma), model))) === 1
    @test length(collect(filter(as_node(Normal), model))) === 1

    @test length(filter(label -> is_data(getproperties(model[label])), collect(filter(as_variable(), model)))) === 4
    @test length(filter(label -> is_random(getproperties(model[label])), collect(filter(as_variable(), model)))) === 3
    @test length(filter(label -> is_constant(getproperties(model[label])), collect(filter(as_variable(), model)))) === 0
end

@testitem "Simple model with lazy data (vector) creation" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, index, getproperties, is_kind

    @model function simple_submodel_3(T, x, y, Λ)
        T ~ Normal(x + y, Λ)
    end

    @model function simple_model_3(y, Σ, n, T)
        m ~ Beta(1, 1)
        for i in 1:n, j in 1:n
            T[i, j] ~ simple_submodel_3(x = m, Λ = Σ, y = y[i])
        end
    end

    @testset for n in 5:10
        model = create_model(simple_model_3(n = n)) do model, ctx
            T = getorcreate!(model, ctx, NodeCreationOptions(kind = :data_for_T), :T, LazyIndex())
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data_for_y), :y, LazyIndex())
            Σ = getorcreate!(model, ctx, NodeCreationOptions(kind = :data_for_Σ), :Σ, LazyIndex())
            return (T = T, y = y, Σ = Σ)
        end

        @test length(collect(filter(as_node(Beta), model))) === 1
        @test length(collect(filter(as_node(Normal), model))) === n^2
        @test length(collect(filter(as_variable(:T), model))) === n^2
        @test length(collect(filter(as_variable(:Σ), model))) === 1
        @test length(collect(filter(as_variable(:y), model))) === n

        # test that options are preserved
        @test all(label -> is_kind(getproperties(model[label]), :data_for_T), collect(filter(as_variable(:T), model)))
        @test all(label -> is_kind(getproperties(model[label]), :data_for_y), collect(filter(as_variable(:y), model)))
        @test all(label -> is_kind(getproperties(model[label]), :data_for_Σ), collect(filter(as_variable(:Σ), model)))

        # test that indices are of expected shape
        Tsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:T), model)))
        Σsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:Σ), model)))
        ysindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:y), model)))

        @test allunique(Tsindices)
        @test Set(Tsindices) == Set(((i, j) for i in 1:n, j in 1:n))

        @test allunique(Σsindices)
        @test Set(Σsindices) == Set([nothing])

        @test allunique(ysindices)
        @test Set(ysindices) == Set(1:n)
    end
end

@testitem "Simple model with lazy data creation with attached data" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, index, getproperties, is_kind

    @model function simple_model_4_withlength(y, Σ)
        m ~ Beta(1, 1)

        for i in 1:length(y)
            y[i] ~ Normal(m, Σ)
        end
    end

    @model function simple_model_4_withsize(y, Σ)
        m ~ Beta(1, 1)

        for i in 1:size(y, 1)
            y[i] ~ Normal(m, Σ)
        end
    end

    @model function simple_model_4_witheachindex(y, Σ)
        m ~ Beta(1, 1)

        for i in eachindex(y)
            y[i] ~ Normal(m, Σ)
        end
    end

    @model function simple_model_4_with_firstindex_lastindex(y, Σ)
        m ~ Beta(1, 1)

        for i in firstindex(y):lastindex(y)
            y[i] ~ Normal(m, Σ)
        end
    end

    @model function simple_model_4_with_forloop(y, Σ)
        m ~ Beta(1, 1)

        for yᵢ in y
            yᵢ ~ Normal(m, Σ)
        end
    end

    @model function simple_model_4_with_foreach(y, Σ)
        m ~ Beta(1, 1)

        foreach(y) do yᵢ
            yᵢ ~ Normal(m, Σ)
        end
    end

    models = [
        simple_model_4_withlength,
        simple_model_4_witheachindex,
        simple_model_4_withsize,
        simple_model_4_with_firstindex_lastindex,
        simple_model_4_with_forloop,
        simple_model_4_with_foreach
    ]

    @testset for n in 5:10, model in models
        ydata = rand(n)
        Σdata = Matrix(ones(n, n))

        model = create_model(model()) do model, ctx
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata))
            Σ = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :Σ, LazyIndex(Σdata))

            # Check also that the methods are redirected properly
            @test length(ydata) === length(y)
            @test size(ydata) === size(y)
            @test size(ydata, 1) === size(y, 1)
            @test firstindex(ydata) === firstindex(y)
            @test lastindex(ydata) === lastindex(y)
            @test eachindex(ydata) === eachindex(y)
            @test axes(ydata) === axes(y)

            @test length(Σdata) === length(Σ)
            @test size(Σdata) === size(Σ)
            @test size(Σdata, 1) === size(Σ, 1)
            @test size(Σdata, 2) === size(Σ, 2)
            @test firstindex(Σdata) === firstindex(Σ)
            @test lastindex(Σdata) === lastindex(Σ)
            @test eachindex(Σdata) === eachindex(Σ)
            @test axes(Σdata) === axes(Σ)

            return (y = y, Σ = Σ)
        end

        @test length(collect(filter(as_node(Beta), model))) === 1
        @test length(collect(filter(as_node(Normal), model))) === n
        @test length(collect(filter(as_variable(:Σ), model))) === 1
        @test length(collect(filter(as_variable(:y), model))) === n

        # test that options are preserved
        @test all(label -> is_kind(getproperties(model[label]), :data), collect(filter(as_variable(:Σ), model)))

        # test that indices are of expected shape
        Σsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:Σ), model)))
        ysindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:y), model)))

        @test allunique(Σsindices)
        @test Set(Σsindices) == Set([nothing])

        @test allunique(ysindices)
        @test Set(ysindices) == Set(1:n)
    end

    # Test errors
    @testset for n in 5:10, model in models
        @test_throws "is not defined for a lazy node label without data attached" create_model(model()) do model, ctx
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex())
            Σ = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :Σ, LazyIndex())

            return (y = y, Σ = Σ)
        end
    end
end

@testitem "Simple model with lazy data creation with attached data but out of bounds" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, index, getproperties, is_kind

    @model function simple_model_a_vector(a)
        x ~ Beta(a[1], a[2]) # In the test the provided `a` will either a scalar or a vector of length 1
        y ~ Gamma(a[3], a[4])
        z ~ Normal(x, y)
    end

    @testset "simple_model_a_vector: `a` is a scalar" begin
        @test_throws "The index `[1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_vector()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex(1))
            return (a = a,)
        end

        @test_throws "The index `[1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_vector()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex(1.0))
            return (a = a,)
        end
    end

    @testset "simple_model_a_vector: `a`` is a vector, but length is less than required in the model" begin
        @test_throws "The index `[1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_vector()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([]))
            return (a = a,)
        end

        @test_throws "The index `[2]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_vector()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([1]))
            return (a = a,)
        end

        @test_throws "The index `[3]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_vector()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([1.0, 1.0]))
            return (a = a,)
        end

        @test_throws "The index `[4]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_vector()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([1.0, 1.0, 1.0]))
            return (a = a,)
        end
    end

    @model function simple_model_a_matrix(a)
        x ~ Beta(a[1, 1], a[1, 2]) # In the test the provided `a` will either a scalar or a matrix of smaller size
        y ~ Gamma(a[2, 1], a[2, 2])
        z ~ Normal(x, y)
    end

    @testset "simple_model_a_matrix: `a` is a scalar" begin
        @test_throws "The index `[1, 1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex(1))
            return (a = a,)
        end

        @test_throws "The index `[1, 1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex(1.0))
            return (a = a,)
        end
    end

    @testset "simple_model_a_matrix: `a` is a vector" begin
        @test_throws "The index `[1, 1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([]))
            return (a = a,)
        end

        # Here it is a bit tricky, because the `a` is a vector, however Julia allows doing `a[1, 1]` even if `a` is a vector
        # So it starts erroring only on `[1, 2]`
        @test_throws "The index `[1, 2]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([1.0, 1.0, 1.0, 1.0]))
            return (a = a,)
        end
    end

    @testset "simple_model_a_matrix: `a` is a matrix" begin
        @test_throws "The index `[1, 1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([;;]))
            return (a = a,)
        end

        @test_throws "The index `[2, 1]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([1.0 1.0;]))
            return (a = a,)
        end

        @test_throws "The index `[1, 2]` is not compatible with the underlying collection provided for the label `a`." create_model(
            simple_model_a_matrix()
        ) do model, ctx
            a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, LazyIndex([1.0; 1.0]))
            return (a = a,)
        end
    end
end

@testitem "Simple state space model" begin
    using Distributions

    import GraphPPL: create_model, add_toplevel_model!, degree

    # Test that graph construction creates the right amount of nodes and variables in a simple state space model
    @model function state_space_model(n)
        γ ~ Gamma(1, 1)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], γ)
        for i in 2:n
            x[i] ~ Normal(x[i - 1], 1)
            y[i] ~ Normal(x[i], γ)
        end
    end
    for n in [10, 30, 50, 100, 1000]
        model = create_model()
        add_toplevel_model!(model, state_space_model, (n = n,))
        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_variable(:x), model))) == n
        @test length(collect(filter(as_variable(:y), model))) == n

        @test all(v -> degree(model, v) === 3, collect(filter(as_variable(:x), model))[1:(end - 1)]) # Intermediate entries have degree `3`
        @test all(v -> degree(model, v) === 2, collect(filter(as_variable(:x), model))[end:end]) # The last entry has degree `2`

        @test all(v -> degree(model, v) === 1, filter(as_variable(:y), model)) # The data entries have degree `1`

        @test length(collect(filter(as_node(Gamma), model))) == 1
        @test length(collect(filter(as_variable(:γ), model))) == 1
        @test all(v -> degree(model, v) === n + 1, filter(as_variable(:γ), model)) # The shared variable should have degree `n + 1` (1 for the prior and `n` for the likelihoods)
    end
end

@testitem "Simple state space model with lazy data creation with attached data" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, index, getproperties, is_random, is_data, degree

    @model function state_space_model_with_lazy_data(y, Σ)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], Σ)
        for i in 2:length(y)
            x[i] ~ Normal(x[i - 1], 1)
            y[i] ~ Normal(x[i], Σ)
        end
    end

    for n in 5:10
        ydata = ones(n)
        Σdata = ones(n, n)

        model = GraphPPL.create_model(state_space_model_with_lazy_data()) do model, ctx
            y = GraphPPL.getorcreate!(model, ctx, GraphPPL.NodeCreationOptions(kind = :data), :y, GraphPPL.LazyIndex(ydata))
            Σ = GraphPPL.getorcreate!(model, ctx, GraphPPL.NodeCreationOptions(kind = :data), :Σ, GraphPPL.LazyIndex(Σdata))
            return (y = y, Σ = Σ)
        end

        @test length(collect(filter(as_node(Normal), model))) === 2n
        @test length(collect(filter(as_variable(:Σ), model))) === 1
        @test length(collect(filter(as_variable(:y), model))) === n
        @test length(collect(filter(as_variable(:x), model))) === n

        # # test that options are preserved
        @test all(label -> is_random(getproperties(model[label])), collect(filter(as_variable(:x), model)))
        @test all(label -> is_data(getproperties(model[label])), collect(filter(as_variable(:y), model)))
        @test all(label -> is_data(getproperties(model[label])), collect(filter(as_variable(:Σ), model)))

        # # test that indices are of expected shape
        Σsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:Σ), model)))
        xsindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:x), model)))
        ysindices = map((label) -> index(getproperties(model[label])), collect(filter(as_variable(:y), model)))

        @test allunique(Σsindices)
        @test Set(Σsindices) == Set([nothing])

        @test allunique(xsindices)
        @test Set(xsindices) == Set(1:n)

        @test allunique(ysindices)
        @test Set(ysindices) == Set(1:n)

        # Test that the `x` variables are connected to 3 nodes (except for the last one)
        @test all(v -> degree(model, v) === 3, collect(filter(as_variable(:x), model))[1:(end - 1)]) # Intermediate entries have degree `3`
        @test all(v -> degree(model, v) === 2, collect(filter(as_variable(:x), model))[end:end]) # The last entry has degree `2`
    end
end

@testitem "Nested model structure" begin
    using Distributions

    import GraphPPL: create_model, add_toplevel_model!
    # Test that graph construction creates the right amount of nodes and variables in a nested model structure

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
            x_3[i] ~ Normal(μ = x_3[i - 1], σ = ξ)
            x_2[i] ~ gcv(x = x_2[i - 1], z = x_3[i], ω = ω_2, κ = κ_2)
            x_1[i] ~ gcv_lm(x_prev = x_1[i - 1], z = x_2[i], ω = ω_1, κ = κ_1, y = y[i - 1])
        end
    end

    for n in [10, 30, 50, 100, 1000]
        model = GraphPPL.create_model(hgf()) do model, context
            for i in 1:n
                GraphPPL.getorcreate!(model, context, :y, i)
            end
            return (y = GraphPPL.getorcreate!(model, context, :y, 1),)
        end

        @test length(collect(filter(as_node(Normal), model))) == (4 * n) + 7
        @test length(collect(filter(as_node(exp), model))) == 2 * n
        @test length(collect(filter(as_node(prod), model))) == 2 * n
        @test length(collect(filter(as_node(sum), model))) == 2 * n
        @test length(collect(filter(as_node(Gamma), model))) == 1
        @test length(collect(filter(as_node(Normal) & as_context(gcv), model))) == 2 * n
        @test length(collect(filter(as_variable(:x_1), model))) == n + 1
    end
end

@testitem "Force create a new variable with the `new` syntax" begin
    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions

    @model function submodel(y, x_prev, x_next)
        x_next ~ Normal(x_prev, 1)
        y ~ Normal(x_next, 1)
    end

    @model function state_space_model(y)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:length(y)
            # `x[i]` is not defined here, so this should fail
            y[i] ~ submodel(x_next = x[i], x_prev = x[i - 1])
        end
    end

    ydata = ones(10)

    @test_throws BoundsError create_model(state_space_model()) do model, ctx
        y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata))
        return (y = y,)
    end

    @model function state_space_model_with_new(y)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:length(y)
            # `x[i]` is not defined here, so this should fail
            y[i] ~ submodel(x_next = new(x[i]), x_prev = x[i - 1])
        end
    end

    model = create_model(state_space_model_with_new()) do model, ctx
        y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata))
        return (y = y,)
    end

    @test length(collect(filter(as_node(Normal), model))) === 20
    @test length(collect(filter(as_variable(:x), model))) === 10
    @test length(collect(filter(as_variable(:y), model))) === 10

end