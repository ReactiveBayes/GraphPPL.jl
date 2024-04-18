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

    include("testutils.jl")

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
    import GraphPPL: create_model, getcontext, getorcreate!, add_toplevel_model!, as_node, NodeCreationOptions, prune!

    include("testutils.jl")

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

    include("testutils.jl")

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
    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, is_data, is_constant, is_random, getproperties

    include("testutils.jl")

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
    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, MissingCollection, index, getproperties, is_kind

    include("testutils.jl")

    @model function simple_submodel_3(T, x, y, Λ)
        T ~ Normal(x + y, Λ)
    end

    @model function simple_model_3(y, Σ, n, T)
        m ~ Beta(1, 1)
        for i in 1:n, j in 1:n
            T[i, j] ~ simple_submodel_3(x = m, Λ = Σ, y = y[i])
        end
    end

    @test LazyIndex() === LazyIndex(MissingCollection())
    @test LazyIndex(missing) === LazyIndex(MissingCollection())

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

    include("testutils.jl")

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

    include("testutils.jl")

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

    include("testutils.jl")

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
        model = create_test_model()
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

    include("testutils.jl")

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

    include("testutils.jl")

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

    include("testutils.jl")

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

@testitem "Anonymous variables should not be created from arithmetical operations on pure constants" begin
    using Distributions, LinearAlgebra
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex, variable_nodes, getproperties, is_random, getname

    include("testutils.jl")

    @model function mv_iid_inverse_wishart_known_mean(y, d)
        m ~ MvNormal(zeros(d + 1 - 1 + 1 - 1), Matrix(Diagonal(ones(d + 1 - 1 + 1 - 1))))
        C ~ InverseWishart(d + 1, Matrix(Diagonal(ones(d))))

        for i in eachindex(y)
            y[i] ~ MvNormal(m, C)
        end
    end

    ydata = rand(10)

    for d in 1:3
        model = create_model(mv_iid_inverse_wishart_known_mean(d = d)) do model, ctx
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata))
            return (y = y,)
        end

        variable_nodes(model) do label, nodedata
            properties = getproperties(nodedata)
            if is_random(properties)
                # Shouldn't be any anonymous variables here
                @test getname(properties) ∈ (:C, :m)
            end
        end

        @test length(collect(filter(as_node(MvNormal), model))) === 11
        @test length(collect(filter(as_node(InverseWishart), model))) === 1
        @test length(collect(filter(as_node(Matrix), model))) === 0
        @test length(collect(filter(as_node(Diagonal), model))) === 0
        @test length(collect(filter(as_node(ones), model))) === 0
        @test length(collect(filter(as_node(+), model))) === 0
        @test length(collect(filter(as_node(-), model))) === 0
        @test length(collect(filter(as_node(sum), model))) === 0
        @test length(collect(filter(as_variable(:C), model))) === 1
        @test length(collect(filter(as_variable(:m), model))) === 1
    end
end

@testitem "Aliases in the model should be resolved automatically" begin
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, fform, factor_nodes, getproperties

    include("testutils.jl")

    @model function aliases_for_normal(s4)
        r1 ~ Normal(μ = 1.0, τ = 1.0)
        r2 ~ Normal(m = r1, γ = 1.0)
        r3 ~ Normal(mean = r2, σ⁻² = 1.0)
        r4 ~ Normal(mean = r3, w = 1.0)
        r5 ~ Normal(mean = r4, p = 1.0)
        r6 ~ Normal(mean = r5, prec = 1.0)
        r7 ~ Normal(mean = r6, precision = 1.0)

        s1 ~ Normal(m = r7, τ⁻¹ = 1.0)
        s2 ~ Normal(mean = s1, v = 1.0)
        s3 ~ Normal(mean = s2, var = 1.0)
        s4 ~ Normal(mean = s3, variance = 1.0)
    end

    model = create_model(aliases_for_normal()) do model, ctx
        return (; s4 = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :s4, nothing))
    end

    # `as_node(Normal)` does take into account the aliasing, so it reports both `NormalMeanPrecision` and `NormalMeanVariance`
    @test length(collect(filter(as_node(Normal), model))) === 11
    # The manual search however does indicate that the aliases are resolved and `Normal` node has NOT been created (as intended)
    @test length(collect(filter(label -> fform(getproperties(model[label])) === Normal, collect(factor_nodes(model))))) === 0
    # Double check the number of `NormalMeanPrecision` and `NormalMeanVariance` nodes
    @test length(collect(filter(as_node(NormalMeanPrecision), model))) === 7
    @test length(collect(filter(as_node(NormalMeanVariance), model))) === 4
end

@testitem "Submodels can be used in the keyword arguments" begin
    using Distributions, LinearAlgebra
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex, variable_nodes, getproperties, is_random, getname

    include("testutils.jl")

    @model function prod_distributions(a, b, c)
        a ~ b * c
    end

    # The test tests if we can write `μ = prod_distributions(b = A, c = x_prev)`
    @model function state_transition_with_submodel(y_next, x_next, x_prev, A, B, P, Q)
        x_next ~ MvNormal(μ = prod_distributions(b = A, c = x_prev), Σ = Q)
        y_next ~ MvNormal(μ = prod_distributions(b = B, c = x_next), Σ = P)
    end

    @model function multivariate_lgssm_model_with_several_submodels(y, mean0, cov0, A, B, Q, P)
        x_prev ~ MvNormal(μ = mean0, Σ = cov0)
        for i in eachindex(y)
            x[i] ~ state_transition_with_submodel(y_next = y[i], x_prev = x_prev, A = A, B = B, P = P, Q = Q)
            x_prev = x[i]
        end
    end

    ydata = rand(10)
    A = rand(3, 3)
    B = rand(3, 3)
    Q = rand(3, 3)
    P = rand(3, 3)
    mean0 = rand(3)
    cov0 = rand(3, 3)

    model =
        create_model(multivariate_lgssm_model_with_several_submodels(mean0 = mean0, cov0 = cov0, A = A, B = B, Q = Q, P = P)) do model, ctx
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata))
            return (y = y,)
        end

    @test length(collect(filter(as_node(MvNormal), model))) === 21
    @test length(collect(filter(as_node(prod), model))) === 20

    @test length(collect(filter(as_variable(:a), model))) === 0
    @test length(collect(filter(as_variable(:b), model))) === 0
    @test length(collect(filter(as_variable(:x), model))) === 10
end

@testitem "Using distribution objects as priors" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex

    include("testutils.jl")

    @model function coin_model_priors(y, prior)
        θ ~ prior
        for i in eachindex(y)
            y[i] ~ Bernoulli(θ)
        end
    end

    ydata = rand(10)
    prior = Beta(1, 1)

    model = create_model(coin_model_priors(prior = prior)) do model, context
        return (; y = getorcreate!(model, context, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata)))
    end

    @test length(collect(filter(as_node(Bernoulli), model))) === 10
    @test length(collect(filter(as_node(prior), model))) === 1
end

@testitem "Model that passes a slice to child model" begin
    using GraphPPL
    include("testutils.jl")

    @model function mixed_v(y, v)
        for i in 1:3
            v[i] ~ Normal(0, 1)
        end
        y ~ Normal(v[1], v[2])
    end

    @model function mixed_m()
        local m
        for i in 1:3
            for j in 1:3
                m[i, j] ~ Normal(0, 1)
            end
        end
        y ~ mixed_v(v = m[:, 1])
    end

    model = GraphPPL.create_model(mixed_m())
    context = GraphPPL.getcontext(model)

    @test haskey(context[mixed_v, 1], :v)
end

@testitem "Model that constructs a new array to pass to children" begin
    using GraphPPL
    include("testutils.jl")

    @model function mixed_v(y, v)
        for i in 1:3
            v[i] ~ Normal(0, 1)
        end
        y ~ Normal(v[1], v[2])
    end

    @model function mixed_m()
        v1 ~ Normal(0, 1)
        v2 ~ Normal(0, 1)
        v3 ~ Normal(0, 1)
        y ~ mixed_v(v = [v1, v2, v3])
    end

    model = GraphPPL.create_model(mixed_m())
    context = GraphPPL.getcontext(model)

    @test haskey(context[mixed_v, 1], :v)

    @model function mixed_v(y, v)
        for i in 1:3
            v[i] ~ Normal(0, 1)
        end
        y ~ Normal(v[1], v[2])
    end

    @model function mixed_m()
        v1 ~ Normal(0, 1)
        v2 ~ Normal(0, 1)
        v3 ~ Normal(0, 1)
        v = Matrix([v1 v2; v1 v3])
        y ~ mixed_v(v = v)
    end

    @test_throws GraphPPL.NotImplementedError local model = GraphPPL.create_model(mixed_m())
end

@testitem "Model creation should throw if a `~` using with a constant on RHS" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex

    include("testutils.jl")

    @model function broken_beta_bernoulli(y)
        # This should throw an error since `Matrix` is not defined as a proper node
        θ ~ Matrix([1.0 0.0; 0.0 1.0])
        for i in eachindex(y)
            y[i] ~ Bernoulli(θ)
        end
    end

    @test_throws "`Matrix` cannot be used as a factor node. Both the arguments and the node are not stochastic." create_model(
        broken_beta_bernoulli()
    ) do model, context
        return (; y = getorcreate!(model, context, NodeCreationOptions(kind = :data), :y, LazyIndex(rand(10))))
    end
end

@testitem "Condition based initialization of variables" begin
    using Distributions
    import GraphPPL: create_model

    include("testutils.jl")

    @model function condition_based_initialization(condition)
        if condition
            y ~ Normal(0.0, 1.0)
        else
            y ~ Gamma(1.0, 1.0)
        end
    end

    model1 = create_model(condition_based_initialization(condition = true))
    model2 = create_model(condition_based_initialization(condition = false))

    @test length(collect(filter(as_variable(:y), model1))) == 1
    @test length(collect(filter(as_variable(:y), model2))) == 1

    @test length(collect(filter(as_node(Normal), model1))) == 1
    @test length(collect(filter(as_node(Gamma), model1))) == 0

    @test length(collect(filter(as_node(Normal), model2))) == 0
    @test length(collect(filter(as_node(Gamma), model2))) == 1
end

@testitem "Attempt to trick Julia's parser" begin
    using Distributions
    import GraphPPL: create_model

    include("testutils.jl")

    # We use `@isdefined` macro inside the macro generator code to check if the variable is defined
    # The idea of this test is to double check that `@model` parser and Julia in particular 
    # does not confuse the undefined `y` variable with the `y` variable defined in the model
    @model function tricky_model_1()
        y ~ Normal(0.0, 1.0)
        if false
            y = nothing
        end
    end

    @model function tricky_model_2()
        y ~ Normal(0.0, 1.0)
        if false
            y = nothing
        end
        local y
    end

    for modelfn in [tricky_model_1, tricky_model_2]
        model_3 = create_model(modelfn())
        @test length(collect(filter(as_variable(:y), model_3))) == 1
        @test length(collect(filter(as_node(Normal), model_3))) == 1
    end

    global yy = 1

    @model function tricky_model_3()
        yy ~ Normal(0.0, 1.0)
        # This is technically not allowed in real models 
        # However we want the `@model` macro to instantiate a different `yy` variable 
        # and not confuse it with the global `yy`. We "override" `yy` but since its a local 
        # random variable it should not override the global `yy` which is tested below
        yy = 2
    end

    # Test before model creation
    @test yy === 1

    model_3 = create_model(tricky_model_3())

    @test length(collect(filter(as_variable(:yy), model_3))) == 1
    @test length(collect(filter(as_node(Normal), model_3))) == 1
    # We test here that the `@model` macro does not confuse the global `yy` in the model after model creation
    @test yy === 1

    # We double check though that the `@model` macro may depend on global variables if needed
    global boolean = true
    @model function model_that_uses_global_variables_1()
        if boolean
            y ~ Normal(0.0, 1.0)
        else
            y ~ Gamma(1.0, 1.0)
        end
    end

    model_4 = create_model(model_that_uses_global_variables_1())

    @test length(collect(filter(as_variable(:y), model_4))) == 1
    @test length(collect(filter(as_node(Normal), model_4))) == 1
    @test length(collect(filter(as_node(Gamma), model_4))) == 0

    global m = 0.0
    global v = 1.0
    @model function model_that_uses_global_variables_2()
        y ~ Normal(m, v)
    end

    model_5 = create_model(model_that_uses_global_variables_1())

    @test length(collect(filter(as_variable(:y), model_5))) == 1
    @test length(collect(filter(as_node(Normal), model_5))) == 1
    @test length(collect(filter(as_node(Gamma), model_5))) == 0

    normalnode = first(collect(filter(as_node(Normal), model_5)))
    nodeneighborsproperties = map(GraphPPL.getproperties, GraphPPL.neighbor_data(GraphPPL.getproperties(model_5[normalnode])))

    @test GraphPPL.is_constant(nodeneighborsproperties[2]) && GraphPPL.value(nodeneighborsproperties[2]) === m
    @test GraphPPL.is_constant(nodeneighborsproperties[3]) && GraphPPL.value(nodeneighborsproperties[3]) === v
end

@testitem "Broadcasting in the model" begin
    using Distributions
    import GraphPPL: create_model
    using LinearAlgebra

    include("testutils.jl")

    @model function linreg()
        x .~ Normal(fill(0, 10), 1)
        a .~ Normal(fill(0, 10), 1)
        b .~ Normal(fill(0, 10), 1)
        y .~ Normal(mean = x .* b .+ a, var = det((diagm(ones(2)) .+ diagm(ones(2))) ./ 2))
    end

    model = create_model(linreg())
    @test length(collect(filter(as_node(Normal), model))) == 40
    @test length(collect(filter(as_node(sum), model))) == 10
    @test length(collect(filter(as_node(prod), model))) == 10

    @model function nested_normal()
        x .~ Normal(fill(0, 10), 1)
        a .~ Gamma(fill(0, 10), 1)
        y .~ Normal(Normal.(Normal.(x, 1), a), 1)
    end

    model = create_model(nested_normal())
    @test length(collect(filter(as_node(Normal), model))) == 40
    @test length(collect(filter(as_node(Gamma), model))) == 10

    function foo end
    GraphPPL.NodeBehaviour(::TestUtils.TestGraphPPLBackend, ::typeof(foo)) = GraphPPL.Stochastic()

    @model function emtpy_broadcast()
        x .~ Normal(fill(0, 10), 1)
        x .~ foo()
    end

    model = create_model(emtpy_broadcast())
    @test length(collect(filter(as_node(foo), model))) == 10

    @model function coin_toss(x)
        π ~ Beta(1, 1)
        x .~ Bernoulli(π)
    end
    model = create_model(coin_toss()) do model, context
        return (; x = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data), :x, 1:10))
    end
    @test length(collect(filter(as_node(Bernoulli), model))) == 10
    @test length(collect(filter(as_node(Beta), model))) == 1

    @model function weird_broadcast()
        π ~ Beta(1, 1)
        z .~ Bernoulli(Normal.(0, 1))
    end
    @test_throws ErrorException local model = create_model(weird_broadcast())
end

@testitem "Broadcasting with LazyNodeLabel" begin
    using Distributions, LinearAlgebra
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex

    include("testutils.jl")

    @model function linear_regression_broadcasted(x, y)
        a ~ Normal(mean = 0.0, var = 1.0)
        b ~ Normal(mean = 0.0, var = 1.0)
        # Variance over-complicated for a purpose of checking that this expressions are allowed, it should be equal to `1.0`
        y .~ Normal(mean = x .* b .+ a, var = det((diagm(ones(2)) .+ diagm(ones(2))) ./ 2))
    end

    xdata = rand(10)
    ydata = rand(10)

    model = create_model(linear_regression_broadcasted()) do model, ctx
        return (
            x = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, LazyIndex(xdata)),
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :y, LazyIndex(ydata))
        )
    end

    @test length(collect(filter(as_node(Normal), model))) == 12
    @test length(collect(filter(as_node(sum), model))) == 10
    @test length(collect(filter(as_node(prod), model))) == 10
    @test length(collect(filter(as_node(det), model))) == 0
    @test length(collect(filter(as_node(diagm), model))) == 0
    @test length(collect(filter(as_node(ones), model))) == 0

    # `xdata` is not passed
    @test_throws "lazy node label without data attached" create_model(linear_regression_broadcasted()) do model, ctx
        return (
            x = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, LazyIndex()),
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :y, LazyIndex(ydata))
        )
    end

    # `ydata` is not passed
    @test_throws "lazy node label without data attached" create_model(linear_regression_broadcasted()) do model, ctx
        return (
            x = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, LazyIndex(xdata)),
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :y, LazyIndex())
        )
    end

    # both `xdata` and `ydata` are not passed
    @test_throws "lazy node label without data attached" create_model(linear_regression_broadcasted()) do model, ctx
        return (
            x = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, LazyIndex()),
            y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :y, LazyIndex())
        )
    end

    @model function beta_bernoulli_broadcasted(x)
        θ ~ Beta(1, 1)
        x .~ Bernoulli(θ)
    end

    xdata = [1.0, 0.0, 1.0, 0.0]

    model = create_model(beta_bernoulli_broadcasted()) do model, ctx
        return (; x = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, LazyIndex(xdata)),)
    end

    @test length(collect(filter(as_node(Bernoulli), model))) == 4
    @test length(collect(filter(as_node(Beta), model))) == 1
end

@testitem "Ambiguous broadcasting should give a descriptive error" begin
    using Distributions, LinearAlgebra
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex

    include("testutils.jl")

    @model function faulty_beta_bernoulli_broadcasted()
        θ ~ Beta(1, 1)
        x .~ Bernoulli(θ)
    end

    # The error message can be improved though
    @test_throws "Index is required in the `getorcreate!` function for variable `x`" create_model(faulty_beta_bernoulli_broadcasted())
end

@testitem "Broadcasting over ranges" begin
    using Distributions, LinearAlgebra
    import GraphPPL: create_model, getproperties, neighbor_data, is_random, is_constant, value

    include("testutils.jl")

    @model function broadcasting_over_range()
        # Should create 10 `x` variables
        x .~ Normal(ones(10), 1)

        # Apply state space (AR) structure on top of the previous `x` variables
        x[1] ~ Normal(0.0, 1.0)
        # Here it basically says that `xᵢ₊₁ = xᵢ + 1` for `i = 2, ..., 10`
        x[2:end] .~ x[1:(end - 1)] + 1
    end

    model = create_model(broadcasting_over_range())

    @test length(collect(filter(as_node(Normal), model))) == 11
    @test length(collect(filter(as_node(sum), model))) == 9

    xvariables = collect(filter(as_variable(:x), model))

    foreach(enumerate(collect(filter(as_node(sum), model)))) do (i, label)
        nodedata = model[label]
        nodeproperties = getproperties(nodedata)
        nodeneighbor_properties = map(getproperties, neighbor_data(nodeproperties))

        # The first index of the `sum` is xᵢ₊₁
        @test is_random(nodeneighbor_properties[1]) && nodeneighbor_properties[1] === getproperties(model[xvariables[i + 1]])
        # The second index of the `sum` is xᵢ
        @test is_random(nodeneighbor_properties[2]) && nodeneighbor_properties[2] === getproperties(model[xvariables[i]])
        # The third index of the `sum` is the constant `1`
        @test is_constant(nodeneighbor_properties[3]) && value(nodeneighbor_properties[3]) == 1
    end
end

@testitem "Complex ranges with `begin`/`end` should be supported" begin
    using Distributions
    import GraphPPL: create_model, getproperties, neighbor_data, is_constant, value

    include("testutils.jl")

    @model function complex_ranges_with_begin_end_1()
        c = [1.0, 2.0]
        y[1] ~ Normal(0.0, c[begin + 1])
        y[2] ~ Normal(0.0, c[end - 1])
    end

    @testset "Test case 1" begin
        model = create_model(complex_ranges_with_begin_end_1())

        @test length(collect(filter(as_node(Normal), model))) == 2

        normalnodes = collect(filter(as_node(Normal), model))

        c_for_y_1 = getproperties(collect(neighbor_data(getproperties(model[normalnodes[1]])))[3])
        c_for_y_2 = getproperties(collect(neighbor_data(getproperties(model[normalnodes[2]])))[3])
        # The values are swapped intentionally, the first one depends on `c[2]` and the second one on `c[1]`
        @test is_constant(c_for_y_1) && value(c_for_y_1) === 2.0
        @test is_constant(c_for_y_2) && value(c_for_y_2) === 1.0
    end

    @model function complex_ranges_with_begin_end_2()
        c = [1.0, 2.0]
        y .~ Normal(0.0, c[1:(end - 1 + 1)])
    end

    @model function complex_ranges_with_begin_end_3()
        c = [1.0, 2.0]
        y .~ Normal(0.0, c[(begin + 1 - 1):2])
    end

    @model function complex_ranges_with_begin_end_4()
        c = [1.0, 2.0]
        y .~ Normal(0.0, c[(begin + 1 - 1):(end - 1 + 1)])
    end

    @model function complex_ranges_with_begin_end_5()
        c = [1.0, 2.0]
        y .~ Normal(0.0, c[begin:end])
    end

    @testset "Test case 2" for modelfn in [
        complex_ranges_with_begin_end_2, complex_ranges_with_begin_end_3, complex_ranges_with_begin_end_4, complex_ranges_with_begin_end_5
    ]
        model = create_model(modelfn())

        @test length(collect(filter(as_node(Normal), model))) == 2

        normalnodes = collect(filter(as_node(Normal), model))

        c_for_y_1 = getproperties(collect(neighbor_data(getproperties(model[normalnodes[1]])))[3])
        c_for_y_2 = getproperties(collect(neighbor_data(getproperties(model[normalnodes[2]])))[3])
        @test is_constant(c_for_y_1) && value(c_for_y_1) === 1.0
        @test is_constant(c_for_y_2) && value(c_for_y_2) === 2.0
    end
end

@testitem "Anonymous variables" begin
    using GraphPPL
    import GraphPPL: create_model, VariableNameAnonymous

    include("testutils.jl")

    # Test whether generic anonymous variables are created correctly
    @model function anonymous_variables()
        y ~ Normal(Normal(0, 1), 1)
    end

    model = create_model(anonymous_variables())
    @test length(collect(filter(as_node(Normal), model))) == 2
    @test length(collect(filter(as_variable(VariableNameAnonymous), model))) == 1

    # Test whether anonymous variables are created correctly when we pass a deterministic function with stochastic inputs as an argument

    function foo end

    @model function det_anonymous_variables()
        y .~ Bernoulli(fill(0.5, 10))
        x ~ foo(foo(in = y))
    end

    model = create_model(det_anonymous_variables())
    @test length(collect(filter(as_node(foo), model))) == 2
    @test length(collect(filter(as_variable(VariableNameAnonymous), model))) == 1
end

@testitem "data/const variables should automatically fold when used with anonymous variable and deterministic relationship" begin
    import GraphPPL:
        create_model,
        getorcreate!,
        NodeCreationOptions,
        LazyIndex,
        is_constant,
        is_data,
        getproperties,
        variable_nodes,
        value,
        VariableNameAnonymous

    include("testutils.jl")

    @model function fold_datavars_1(f, a, b)
        y ~ Normal(f(a, b), 0.5)
    end

    @model function fold_datavars_2(f, a, b)
        y ~ Normal(f(f(a, b), f(a, b)), 0.5)
    end

    for f in (+, *, (a, b) -> a + b, (a, b) -> a * b)
        @testset "fold_datavars_1 with just constants" begin
            # Both `a` and `b` are just constant
            model = create_model(fold_datavars_1(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.15), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.87), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 1
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 0

            # In this case the `@model` macro should create an anonymous constvar for `f(a, b)`
            # since all inputs are constants and the relationship is deterministic
            constvars = filter(label -> is_constant(getproperties(model[label])), collect(variable_nodes(model)))
            @test length(constvars) === 4
            @test count(constvars -> value(getproperties(model[constvars])) === 0.15, constvars) === 1
            @test count(constvars -> value(getproperties(model[constvars])) === 0.87, constvars) === 1
            @test count(constvars -> value(getproperties(model[constvars])) === f(0.15, 0.87), constvars) === 1
        end

        @testset "fold_datavars_1 with constants and datavars" begin
            # Both `a` and `b` are datavars, in this case `@model` macro should create a new data variable
            # with the value referencing `f` function
            model = create_model(fold_datavars_1(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 1

            datavars = filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))
            @test length(datavars) === 3
            @test count(
                datavars -> !isnothing(value(getproperties(model[datavars]))) && first(value(getproperties(model[datavars]))) === f,
                datavars
            ) === 1

            # `a` and `b` are either const or datavars
            model = create_model(fold_datavars_1(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 1.0), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 1
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 2

            # `a` and `b` are either const or datavars
            model = create_model(fold_datavars_1(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 1.0), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 1
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 2

            # `a` and `b` are either const or datavars
            model = create_model(fold_datavars_1(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :a, nothing)
                b = 1.0
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 1
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 2

            foreach(collect(filter(as_variable(VariableNameAnonymous), model))) do label
                nodedata = model[label]
                nodeproperties = getproperties(nodedata)
                fform, args = value(nodeproperties)

                @test fform === f
                @test length(args) === 2
                @test args[2] === 1.0
            end
        end

        @testset "fold_datavars_2 with just constants" begin
            # Both `a` and `b` are just constant
            model = create_model(fold_datavars_2(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.15), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.87), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 3
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 0

            constvars = filter(label -> is_constant(getproperties(model[label])), collect(variable_nodes(model)))
            @test length(constvars) === 6
            @test count(constvars -> value(getproperties(model[constvars])) === 0.15, constvars) === 1
            @test count(constvars -> value(getproperties(model[constvars])) === 0.87, constvars) === 1
            @test count(constvars -> value(getproperties(model[constvars])) === f(0.15, 0.87), constvars) === 2
            @test count(constvars -> value(getproperties(model[constvars])) === f(f(0.15, 0.87), f(0.15, 0.87)), constvars) === 1
        end

        @testset "fold_datavars_2 with constants and datavars" begin
            # Both `a` and `b` are datavars
            model = create_model(fold_datavars_2(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 3
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 5

            # `a` and `b` are either const or datavars
            model = create_model(fold_datavars_2(f = f)) do model, ctx
                a = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 1.0), :a, nothing)
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 3
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 4

            # `a` and `b` are either const or datavars
            model = create_model(fold_datavars_2(f = f)) do model, ctx
                a = 1.0
                b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
                return (a = a, b = b)
            end

            @test length(collect(filter(as_node(f), model))) === 0
            @test length(collect(filter(as_node(Normal), model))) === 1
            @test length(collect(filter(as_variable(VariableNameAnonymous), model))) === 3
            @test length(filter(label -> is_data(getproperties(model[label])), collect(variable_nodes(model)))) === 4
        end
    end
end

@testitem "return value from the `@model` should be saved in the Context" begin
    using Distributions
    import GraphPPL: create_model, LazyIndex, getorcreate!, NodeCreationOptions, returnval, getcontext, children

    include("testutils.jl")

    @model function submodel_with_return(y, x, z, subval)
        y ~ Normal(x, z)
        return subval
    end

    @model function model_with_return(y, val)
        x .~ Normal(ones(10), ones(10))
        z .~ Normal(ones(10), ones(10))

        # The purpose of this call is to have another `return` statement in the model
        # The real `return` statement is outside of the anonymous function
        function anonymous_inside()
            for i in 1:10
                y[i] ~ submodel_with_return(x = x[i], z = z[i], subval = (i, "hello world!"))
            end
            return "this value should not be returned"
        end

        anonymous_inside()

        return val
    end

    for topval in (1, [1, 1], ("hello", "world!"))
        model = create_model(model_with_return(val = topval)) do model, ctx
            return (y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :y, LazyIndex(rand(10))),)
        end

        toplevelcontext = getcontext(model)

        @test returnval(toplevelcontext) == topval

        sublevelreturns = []

        # Children are unordered, so we first gather all the return values, sort them and then check
        foreach(children(toplevelcontext)) do subcontext
            push!(sublevelreturns, returnval(subcontext))
        end

        @test sort(sublevelreturns, by = first) == [(i, "hello world!") for i in 1:10]
    end
end

@testitem "`end` index should be allowed in the `~` operator" begin
    import GraphPPL: create_model

    include("testutils.jl")

    @model function begin_end_in_rhs()
        s[1] ~ Beta(0.0, 1.0)
        y[1] ~ Normal(s[begin], 1.0)
        y[2] ~ Normal(s[end], 1.0)
    end

    @testset let model = create_model(begin_end_in_rhs())
        @test length(collect(filter(as_node(Beta), model))) == 1
        @test length(collect(filter(as_node(Normal), model))) == 2
        @test length(collect(filter(as_variable(:s), model))) == 1
    end

    @model function begin_end_in_lhs()
        s[1] ~ Beta(0.0, 1.0)
        s[begin] ~ Normal(0.0, 1.0)
        s[end] ~ Normal(0.0, 1.0)
    end

    @testset let model = create_model(begin_end_in_lhs())
        @test length(collect(filter(as_node(Beta), model))) == 1
        @test length(collect(filter(as_node(Normal), model))) == 2
        @test length(collect(filter(as_variable(:s), model))) == 1
    end
end

@testitem "Use local scoped variable in two different scopes" begin
    import GraphPPL: create_model

    include("testutils.jl")

    @model function scope_twice()
        for i in 1:5
            tmp[i] ~ Normal(0, 1)
        end
        for i in 1:5
            tmp[i] ~ Normal(0, 1)
        end
    end

    @testset let model = create_model(scope_twice())
        @test length(collect(filter(as_node(Normal), model))) == 10
        @test_broken length(collect(filter(as_variable(:tmp), model))) == 10
    end
end

@testitem "LazyIndex should support empty indices if array is passed" begin
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex

    include("testutils.jl")

    @model function foo(y)
        x ~ MvNormal([1, 1], [1 0.0; 0.0 1.0])
        y ~ MvNormal(x, [1.0 0.0; 0.0 1.0])
    end

    model = create_model(foo()) do model, ctx
        return (; y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :y, LazyIndex([1.0, 1.0])))
    end

    @test length(collect(filter(as_node(MvNormal), model))) == 2
    @test length(collect(filter(as_variable(:x), model))) == 1
    @test length(collect(filter(as_variable(:y), model))) == 1
end

@testitem "Node arguments must be unique" begin
    import GraphPPL: create_model, getorcreate!, NodeCreationOptions, LazyIndex

    include("testutils.jl")

    @model function simple_model_duplicate_1()
        x ~ Normal(0.0, 1.0)
        y ~ x + x
    end

    @model function simple_model_duplicate_2()
        x ~ Normal(0.0, 1.0)
        y ~ x + x + x
    end

    @model function simple_model_duplicate_3()
        x ~ Normal(0.0, 1.0)
        y ~ Normal(x, x)
    end

    @model function simple_model_duplicate_4()
        x ~ Normal(0.0, 1.0)
        hide_x = x
        y ~ Normal(hide_x, x)
    end

    @model function simple_model_duplicate_5()
        x ~ Normal(0.0, 1.0)
        x ~ Normal(x, 1)
    end

    @model function simple_model_duplicate_6()
        x ~ Normal(0.0, 1.0)
        hide_x = x
        hide_x ~ Normal(x, 1)
    end

    for modelfn in [
        simple_model_duplicate_1,
        simple_model_duplicate_2,
        simple_model_duplicate_3,
        simple_model_duplicate_4,
        simple_model_duplicate_5,
        simple_model_duplicate_6
    ]
        @test_throws r"Trying to create duplicate edge.*Make sure that all the arguments to the `~` operator are unique.*" create_model(
            modelfn()
        )
    end

    @model function my_model(obs, N, sigma)
        local x
        for i in 1:N
            x[i] ~ Bernoulli(0.5)
        end
        local C
        # This model creation is not allowed since `C` is used twice in the `~` operator
        for i in 1:N
            C ~ C + x[i]
        end
        obs ~ NormalMeanVariance(C, sigma^2)
    end

    @test_throws r"Trying to create duplicate edge.*Make sure that all the arguments to the `~` operator are unique.*" create_model(
        my_model(N = 3, sigma = 1.0)
    ) do model, ctx
        obs = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :obs, LazyIndex(0.0))
        return (obs = obs,)
    end

    @model function my_model(obs, N, sigma)
        local x
        for i in 1:N
            x[i] ~ Bernoulli(0.5)
        end
        accum_C = x[1]
        for i in 2:N
            # Here `next_C` will be used twice on the second iteration 
            next_C ~ accum_C + x[i]
            accum_C = next_C
        end
        obs ~ NormalMeanVariance(accum_C, sigma^2)
    end

    @test_throws r"Trying to create duplicate edge.*Make sure that all the arguments to the `~` operator are unique.*" create_model(
        my_model(N = 3, sigma = 1.0)
    ) do model, ctx
        obs = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :obs, LazyIndex(0.0))
        return (obs = obs,)
    end
end
