@testitem "Empty constraints" begin
    import GraphPPL: VariationalConstraintsPlugin, UnspecifiedConstraints

    @test VariationalConstraintsPlugin() == VariationalConstraintsPlugin(UnspecifiedConstraints)
    @test VariationalConstraintsPlugin(nothing) == VariationalConstraintsPlugin(UnspecifiedConstraints)
end

@testitem "simple @model + various constraints" begin
    using Distributions
    import GraphPPL:
        create_model, with_plugins, PluginsCollection, VariationalConstraintsPlugin, getorcreate!, NodeCreationOptions, hasextra, getextra

    include("../../testutils.jl")

    @model function simple_model()
        x ~ Beta(1, 1)
        t ~ Gamma(1, 1)
        y ~ Normal(x, t)
    end

    @testset "No factorization" begin
        no_factorization_constraint_1 = @constraints begin
            q(x, y, t) = q(x, y, t)
        end

        no_factorization_constraint_2 = @constraints begin
            q(x, y, t) = q(x, t, y)
        end

        no_factorization_constraint_3 = @constraints begin
            q(x, y, t) = q(t, x, y)
        end

        no_factorization_constraint_4 = @constraints begin
            q(x, y, t) = q(t, y, x)
        end

        no_factorization_constraint_5 = @constraints begin
            q(x, y, t) = q(y, x, t)
        end

        no_factorization_constraint_6 = @constraints begin
            q(x, y, t) = q(y, t, x)
        end

        no_factorization_constraint_7 = @constraints begin
            q(y, x, t) = q(x, y, t)
        end

        no_factorization_constraint_8 = @constraints begin
            q(t, y, x) = q(x, y, t)
        end

        no_factorization_constraints = [
            no_factorization_constraint_1,
            no_factorization_constraint_2,
            no_factorization_constraint_3,
            no_factorization_constraint_4,
            no_factorization_constraint_5,
            no_factorization_constraint_6,
            no_factorization_constraint_7,
            no_factorization_constraint_8
        ]

        for constraint in no_factorization_constraints
            model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraint))))

            @test all(filter(as_node(Normal), model)) do node
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1, 2, 3),)
            end
        end
    end

    @testset "q(x, y, t) = q(x, y)q(t)" begin
        structured_factorization_1_1 = @constraints begin
            q(x, y, t) = q(x, y)q(t)
        end

        structured_factorization_1_2 = @constraints begin
            q(x, y, t) = q(y, x)q(t)
        end

        structured_factorization_1_3 = @constraints begin
            q(x, y, t) = q(t)q(y, x)
        end

        structured_factorization_1_4 = @constraints begin
            q(x, y, t) = q(t)q(x, y)
        end

        structured_factorization_1_5 = @constraints begin
            q(y, x, t) = q(x, y)q(t)
        end

        structured_factorization_1_6 = @constraints begin
            q(t, y, x) = q(x, y)q(t)
        end

        # These should be equivalent
        constraints = [
            structured_factorization_1_1,
            structured_factorization_1_2,
            structured_factorization_1_3,
            structured_factorization_1_4,
            structured_factorization_1_5,
            structured_factorization_1_6
        ]

        for constraint in constraints
            model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraint))))

            @test all(filter(as_node(Normal), model)) do node
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1, 2), (3,))
            end
        end
    end

    @testset "q(x, y, t) = q(x)q(y, t)" begin
        structured_factorization_1_1 = @constraints begin
            q(x, y, t) = q(x)q(y, t)
        end

        structured_factorization_1_2 = @constraints begin
            q(x, y, t) = q(x)q(t, y)
        end

        structured_factorization_1_3 = @constraints begin
            q(x, y, t) = q(y, t)q(x)
        end

        structured_factorization_1_4 = @constraints begin
            q(x, y, t) = q(t, y)q(x)
        end

        structured_factorization_1_5 = @constraints begin
            q(y, x, t) = q(x)q(y, t)
        end

        structured_factorization_1_6 = @constraints begin
            q(t, y, x) = q(x)q(y, t)
        end

        # These should be equivalent
        constraints = [
            structured_factorization_1_1,
            structured_factorization_1_2,
            structured_factorization_1_3,
            structured_factorization_1_4,
            structured_factorization_1_5,
            structured_factorization_1_6
        ]

        for constraint in constraints
            model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraint))))

            @test all(filter(as_node(Normal), model)) do node
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1, 3), (2,))
            end
        end
    end

    @testset "q(x, y, t) = q(y)q(x, t)" begin
        structured_factorization_1_1 = @constraints begin
            q(x, y, t) = q(y)q(x, t)
        end

        structured_factorization_1_2 = @constraints begin
            q(x, y, t) = q(y)q(t, x)
        end

        structured_factorization_1_3 = @constraints begin
            q(x, y, t) = q(x, t)q(y)
        end

        structured_factorization_1_4 = @constraints begin
            q(x, y, t) = q(t, x)q(y)
        end

        structured_factorization_1_5 = @constraints begin
            q(y, x, t) = q(y)q(x, t)
        end

        structured_factorization_1_6 = @constraints begin
            q(t, y, x) = q(y)q(x, t)
        end

        # These should be equivalent
        constraints = [
            structured_factorization_1_1,
            structured_factorization_1_2,
            structured_factorization_1_3,
            structured_factorization_1_4,
            structured_factorization_1_5,
            structured_factorization_1_6
        ]

        for constraint in constraints
            model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraint))))

            @test all(filter(as_node(Normal), model)) do node
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1,), (2, 3))
            end
        end
    end

    @testset "q(x, y, t) = q(x)q(y)q(t)" begin
        structured_factorization_1_1 = @constraints begin
            q(x, y, t) = q(x)q(y)q(t)
        end

        structured_factorization_1_2 = @constraints begin
            q(x, y, t) = q(x)q(t)q(y)
        end

        structured_factorization_1_3 = @constraints begin
            q(x, y, t) = q(y)q(x)q(t)
        end

        structured_factorization_1_4 = @constraints begin
            q(x, y, t) = q(y)q(t)q(x)
        end

        structured_factorization_1_5 = @constraints begin
            q(x, y, t) = q(t)q(x)q(y)
        end

        structured_factorization_1_6 = @constraints begin
            q(x, y, t) = q(t)q(y)q(x)
        end

        structured_factorization_1_7 = @constraints begin
            q(y, x, t) = q(y)q(t)q(x)
        end

        structured_factorization_1_8 = @constraints begin
            q(x, t, y) = q(t)q(x)q(y)
        end

        structured_factorization_1_9 = @constraints begin
            q(t, x, y) = q(t)q(y)q(x)
        end

        # These should be equivalent
        constraints = [
            structured_factorization_1_1,
            structured_factorization_1_2,
            structured_factorization_1_3,
            structured_factorization_1_4,
            structured_factorization_1_5,
            structured_factorization_1_6,
            structured_factorization_1_7,
            structured_factorization_1_8,
            structured_factorization_1_9
        ]

        for constraint in constraints
            model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraint))))

            @test all(filter(as_node(Normal), model)) do node
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1,), (2,), (3,))
            end
        end
    end
end

@testitem "simple @model + mean field @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions
    using GraphPPL:
        create_model,
        getcontext,
        getorcreate!,
        add_toplevel_model!,
        as_node,
        NodeCreationOptions,
        hasextra,
        getextra,
        PluginsCollection,
        VariationalConstraintsPlugin,
        with_plugins

    include("../../testutils.jl")

    @model function simple_model(a, b, c)
        x ~ Gamma(α = b, θ = sqrt(c))
        a ~ Normal(μ = x, τ = 1)
    end

    # Here we don't even need to specify anything, because 
    # everything should be factorized out by default

    constraints = @constraints begin end

    # `nothing` here will create a `datavar`
    for a in (nothing,), b in (nothing, 1, 1.0), c in (nothing, 1, 1.0)
        model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraints)))) do model, context
            a = something(a, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :a, nothing))
            b = something(b, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :b, nothing))
            c = something(c, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :c, nothing))
            return (; a, b, c)
        end

        @test all(filter(as_node(Gamma) | as_node(Normal), model)) do node
            interfaces = GraphPPL.edges(model, node)
            @test hasextra(model[node], :factorization_constraint_indices)
            return Tuple.(getextra(model[node], :factorization_constraint_indices)) ===
                   (map(interface -> (interface,), 1:length(interfaces))...,)
        end
    end
end

@testitem "state space model @model + mean field @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions
    using GraphPPL:
        create_model,
        getcontext,
        getorcreate!,
        add_toplevel_model!,
        getextra,
        hasextra,
        as_node,
        NodeCreationOptions,
        getproperties,
        PluginsCollection,
        VariationalConstraintsPlugin,
        with_plugins

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    @model function random_walk(y, a, b)
        x[1] ~ NormalMeanVariance(0, 1)
        y[1] ~ NormalMeanVariance(x[1], 1)

        for i in 2:length(y)
            x[i] ~ NormalMeanPrecision(a * x[i - 1] + b, 1)
            y[i] ~ NormalMeanVariance(x[i], 1)
        end
    end

    empty_constraints = @constraints begin end

    mean_field_constraints = @constraints begin
        q(x) = q(x[begin]) .. q(x[end])
    end

    @testset for n in 1:5
        @testset let constraints = empty_constraints
            model = create_model(
                with_plugins(random_walk(a = 1, b = 2), PluginsCollection(VariationalConstraintsPlugin(constraints)))
            ) do model, context
                return (; y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, 1:n))
            end

            @test length(collect(filter(as_node(Normal), model))) === 2 * n
            @test length(collect(filter(as_node(NormalMeanVariance), model))) === n + 1
            @test length(collect(filter(as_node(NormalMeanPrecision), model))) === n - 1
            @test length(collect(filter(as_node(prod), model))) === n - 1
            @test length(collect(filter(as_node(sum), model))) === n - 1

            @test all(filter(as_node(NormalMeanVariance), model)) do node
                # This must be factorized out just because of the implicit constraint for conststs and datavars
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1,), (2,), (3,))
            end

            @test all(filter(as_node(NormalMeanPrecision), model)) do node
                # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
                # is correctly resolved to structured, since empty constraints do not factorize out this case
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1, 2), (3,))
            end
        end

        @testset let constraints = mean_field_constraints
            model = create_model(
                with_plugins(random_walk(a = 1, b = 2), PluginsCollection(VariationalConstraintsPlugin(constraints)))
            ) do model, context
                return (; y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, 1:n))
            end

            @test length(collect(filter(as_node(Normal), model))) == 2 * n
            @test length(collect(filter(as_node(NormalMeanVariance), model))) === n + 1
            @test length(collect(filter(as_node(NormalMeanPrecision), model))) === n - 1
            @test length(collect(filter(as_node(prod), model))) === n - 1
            @test length(collect(filter(as_node(sum), model))) === n - 1

            @test all(filter(as_node(NormalMeanPrecision) | as_node(NormalMeanVariance), model)) do node
                # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
                # is correctly resolved to mean-field, because `a * x[i - 1] + b` is deterministically linked to `x[i - 1]`, thus 
                # the interfaces must be factorized out
                # The reset are factorized out just because of the implicit constraint for conststs and datavars
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint_indices)
                return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1,), (2,), (3,))
            end
        end
    end
end

@testitem "simple @model + structured @constraints + anonymous variable linked through a deterministic relation with constants/datavars" begin
    using Distributions, LinearAlgebra
    using GraphPPL:
        create_model,
        getcontext,
        getorcreate!,
        add_toplevel_model!,
        getextra,
        hasextra,
        as_node,
        NodeCreationOptions,
        getproperties,
        PluginsCollection,
        VariationalConstraintsPlugin,
        with_plugins

    include("../../testutils.jl")

    @model function simple_model(y, a, b)
        τ ~ Gamma(10, 10) # wrong for MvNormal, but test is for a different purpose
        θ ~ Gamma(10, 10)

        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], θ)

        for i in 2:length(y)
            x[i] ~ MvNormal(a * x[i - 1] + b, τ)
            y[i] ~ Normal(x[i], θ)
        end
    end

    # Here we don't even need to specify anything, because 
    # everything should be factorized out by default

    constraints = @constraints begin
        q(x, τ, θ) = q(x)q(τ)q(θ)
    end

    # `nothing` here will create a `datavar`
    for a in (nothing,), b in (nothing, 1, 1.0), n in (5, 10)
        model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraints)))) do model, context
            a = something(a, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :a, nothing))
            b = something(b, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :b, nothing))
            y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, 1:n)
            return (; a, b, y)
        end

        @test length(collect(filter(as_node(MvNormal), model))) === n - 1

        @test all(filter(as_node(MvNormal), model)) do node
            @test hasextra(model[node], :factorization_constraint_indices)
            interfaces = GraphPPL.interfaces(MvNormal, GraphPPL.static(3))
            # desired constraints 
            desired = Set([(1, 2), (3,)])
            # actual constraints 
            actual = Set(Tuple.(getextra(model[node], :factorization_constraint_indices)))
            return isequal(desired, actual)
        end
    end
end

@testitem "state space @model (nested) + @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions
    using GraphPPL:
        create_model,
        getcontext,
        getorcreate!,
        add_toplevel_model!,
        getextra,
        hasextra,
        as_node,
        NodeCreationOptions,
        getproperties,
        PluginsCollection,
        VariationalConstraintsPlugin,
        with_plugins

    include("../../testutils.jl")

    @model function nested2(u, θ, c, d)
        u ~ Normal(c * θ + d, 1)
    end

    @model function nested1(z, g, a, b)
        z ~ nested2(θ = g, c = a, d = b)
    end

    @model function random_walk(y, a, b)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)

        for i in 2:length(y)
            x[i] ~ nested1(g = x[i - 1], a = a, b = b)
            y[i] ~ Normal(x[i], 1)
        end
    end

    # The all constraints below are technically identical and should resolve to the same thing

    constraints1 = @constraints begin
        q(x) = q(x[begin]) .. q(x[end])
    end

    constraints2 = @constraints begin
        for q in nested1
            q(z, g) = q(z)q(g)
        end
    end

    constraints3 = @constraints begin
        for q in nested1
            for q in nested2
                q(u, θ) = q(u)q(θ)
            end
        end
    end

    constraints4 = @constraints begin
        q(x) = q(x[begin]) .. q(x[end])
        for q in nested1
            q(z, g) = q(z)q(g)
        end
    end

    constraints5 = @constraints begin
        q(x) = q(x[begin]) .. q(x[end])
        for q in nested1
            for q in nested2
                q(u, θ) = q(u)q(θ)
            end
        end
    end

    @testset for n in 1:5, constraints in (constraints1, constraints2, constraints3, constraints4, constraints5)
        model = create_model(
            with_plugins(random_walk(a = 1, b = 2), PluginsCollection(VariationalConstraintsPlugin(constraints)))
        ) do model, context
            return (; y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, 1:n))
        end

        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_node(prod), model))) === n - 1
        @test length(collect(filter(as_node(sum), model))) === n - 1

        @test all(filter(as_node(Normal), model)) do gnode
            @test hasextra(model[gnode], :factorization_constraint_indices)
            # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
            # is correctly resolved to mean-field, because `a * x[i - 1] + b` is deterministically linked to `x[i - 1]`, thus 
            # the interfaces must be factorized out
            # Note that in this particular test we simply test all Gaussian nodes because 
            # other Gaussians are also mean-field due to other (implicit) constraints
            interfaces = GraphPPL.edges(model, gnode)
            return Tuple.(getextra(model[gnode], :factorization_constraint_indices)) === ((1,), (2,), (3,))
        end
    end
end

@testitem "Simple @model + functional form constraints" begin
    using Distributions

    import GraphPPL:
        create_model,
        add_toplevel_model!,
        variable_nodes,
        getextra,
        hasextra,
        as_variable,
        PluginsCollection,
        VariationalConstraintsPlugin,
        with_plugins

    include("../../testutils.jl")

    @model function simple_model_for_fform_constraints()
        x ~ Normal(0, 1)
        y ~ Gamma(1, 1)
        z ~ Normal(x, y)
    end

    struct SomeArbitraryFormConstraint1 end
    struct SomeArbitraryFormConstraint2 end

    @testset "Posterior functional form constraints" begin
        constraints_posterior = @constraints begin
            q(z)::SomeArbitraryFormConstraint1()
        end

        model = create_model(
            with_plugins(simple_model_for_fform_constraints(), PluginsCollection(VariationalConstraintsPlugin(constraints_posterior)))
        )

        zvariables = map(label -> model[label], filter(as_variable(:z), model))
        xvariables = map(label -> model[label], filter(as_variable(:x), model))
        yvariables = map(label -> model[label], filter(as_variable(:y), model))

        @test length(zvariables) === 1
        @test length(xvariables) === 1
        @test length(yvariables) === 1
        @test hasextra(first(zvariables), :posterior_form_constraint)
        @test getextra(first(zvariables), :posterior_form_constraint) === SomeArbitraryFormConstraint1()
        @test !hasextra(first(zvariables), :message_form_constraint)

        @test !hasextra(first(xvariables), :posterior_form_constraint)
        @test !hasextra(first(xvariables), :message_form_constraint)
        @test !hasextra(first(yvariables), :posterior_form_constraint)
        @test !hasextra(first(yvariables), :message_form_constraint)
    end

    @testset "Messages functional form constraints" begin
        constraints_messages = @constraints begin
            μ(z)::SomeArbitraryFormConstraint2()
        end

        model = create_model(
            with_plugins(simple_model_for_fform_constraints(), PluginsCollection(VariationalConstraintsPlugin(constraints_messages)))
        )

        zvariables = map(label -> model[label], filter(as_variable(:z), model))
        xvariables = map(label -> model[label], filter(as_variable(:x), model))
        yvariables = map(label -> model[label], filter(as_variable(:y), model))

        @test length(zvariables) === 1
        @test length(xvariables) === 1
        @test length(yvariables) === 1
        @test hasextra(first(zvariables), :message_form_constraint)
        @test getextra(first(zvariables), :message_form_constraint) === SomeArbitraryFormConstraint2()
        @test !hasextra(first(zvariables), :posterior_form_constraint)

        @test !hasextra(first(xvariables), :posterior_form_constraint)
        @test !hasextra(first(xvariables), :message_form_constraint)
        @test !hasextra(first(yvariables), :posterior_form_constraint)
        @test !hasextra(first(yvariables), :message_form_constraint)
    end

    @testset "Both posteriors and messages functional form constraints" begin
        constraints_both = @constraints begin
            q(z)::SomeArbitraryFormConstraint1()
            μ(z)::SomeArbitraryFormConstraint2()
        end

        model = create_model(
            with_plugins(simple_model_for_fform_constraints(), PluginsCollection(VariationalConstraintsPlugin(constraints_both)))
        )

        zvariables = map(label -> model[label], filter(as_variable(:z), model))
        xvariables = map(label -> model[label], filter(as_variable(:x), model))
        yvariables = map(label -> model[label], filter(as_variable(:y), model))

        @test length(zvariables) === 1
        @test length(xvariables) === 1
        @test length(yvariables) === 1
        @test hasextra(first(zvariables), :posterior_form_constraint)
        @test getextra(first(zvariables), :posterior_form_constraint) === SomeArbitraryFormConstraint1()
        @test hasextra(first(zvariables), :message_form_constraint)
        @test getextra(first(zvariables), :message_form_constraint) === SomeArbitraryFormConstraint2()

        @test !hasextra(first(xvariables), :posterior_form_constraint)
        @test !hasextra(first(xvariables), :message_form_constraint)
        @test !hasextra(first(yvariables), :posterior_form_constraint)
        @test !hasextra(first(yvariables), :message_form_constraint)
    end
end

@testitem "@constraints macro pipeline" begin
    import GraphPPL: create_model, with_plugins, PluginsCollection, VariationalConstraintsPlugin, getname, getextra, hasextra, with_plugins

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    constraints = @constraints begin
        q(x, y) = q(x)q(y)
        q(y, z) = q(y)q(z)
        q(x)::NormalMeanVariance()
        μ(y)::NormalMeanVariance()
    end
    # Test constraints macro with single variables and no nesting
    model = create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraints))))
    ctx = GraphPPL.getcontext(model)

    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], :posterior_form_constraint) == NormalMeanVariance()
        @test !hasextra(model[node], :message_form_constraint)
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], :posterior_form_constraint)
        @test getextra(model[node], :message_form_constraint) == NormalMeanVariance()
    end
    for node in filter(GraphPPL.as_variable(:z), model)
        @test !hasextra(model[node], :posterior_form_constraint)
        @test !hasextra(model[node], :message_form_constraint)
    end
    @test Tuple.(getextra(model[ctx[NormalMeanVariance, 1]], :factorization_constraint_indices)) == ((1,), (2,), (3,))
    @test Tuple.(getextra(model[ctx[NormalMeanVariance, 2]], :factorization_constraint_indices)) == ((1, 2), (3,))

    # Test constriants macro with nested model
    constraints = @constraints begin
        for q in inner
            q(α, θ) = q(α)q(θ)
            q(α)::NormalMeanVariance()
            μ(θ)::NormalMeanVariance()
        end
    end
    model = create_model(with_plugins(outer(), PluginsCollection(VariationalConstraintsPlugin(constraints))))
    ctx = GraphPPL.getcontext(model)

    @test hasextra(model[ctx[:w][1]], :posterior_form_constraint) === false
    @test hasextra(model[ctx[:w][2]], :posterior_form_constraint) === false
    @test hasextra(model[ctx[:w][3]], :posterior_form_constraint) === false
    @test hasextra(model[ctx[:w][4]], :posterior_form_constraint) === false
    @test hasextra(model[ctx[:w][5]], :posterior_form_constraint) === false

    @test hasextra(model[ctx[:w][1]], :message_form_constraint) === false
    @test getextra(model[ctx[:w][2]], :message_form_constraint) === NormalMeanVariance()
    @test getextra(model[ctx[:w][3]], :message_form_constraint) === NormalMeanVariance()
    @test hasextra(model[ctx[:w][4]], :message_form_constraint) === false
    @test hasextra(model[ctx[:w][5]], :message_form_constraint) === false

    @test getextra(model[ctx[:y]], :posterior_form_constraint) == NormalMeanVariance()
    for node in filter(GraphPPL.as_node(NormalMeanVariance) & GraphPPL.as_context(inner_inner), model)
        @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2, 3))
    end

    # Test with specifying specific submodel
    constraints = @constraints begin
        for q in (child_model, 1)
            q(in, out, σ) = q(in, out)q(σ)
        end
    end
    model = create_model(with_plugins(parent_model(), PluginsCollection(VariationalConstraintsPlugin(constraints))))
    ctx = GraphPPL.getcontext(model)

    @test Tuple.(getextra(model[ctx[child_model, 1][NormalMeanVariance, 1]], :factorization_constraint_indices)) == ((1, 2), (3,))
    for i in 2:99
        @test Tuple.(getextra(model[ctx[child_model, i][NormalMeanVariance, 1]], :factorization_constraint_indices)) == ((1, 2, 3),)
    end

    # Test with specifying general submodel
    constraints = @constraints begin
        for q in child_model
            q(in, out, σ) = q(in, out)q(σ)
        end
    end
    model = create_model(with_plugins(parent_model(), PluginsCollection(VariationalConstraintsPlugin(constraints))))
    ctx = GraphPPL.getcontext(model)

    @test Tuple.(getextra(model[ctx[child_model, 1][NormalMeanVariance, 1]], :factorization_constraint_indices)) == ((1, 2), (3,))
    for node in filter(GraphPPL.as_node(NormalMeanVariance) & GraphPPL.as_context(child_model), model)
        @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1, 2), (3,))
    end

    # Test with ambiguous constraints
    constraints = @constraints begin
        q(x, y) = q(x)q(y)
    end
    @test_throws ErrorException create_model(with_plugins(simple_model(), PluginsCollection(VariationalConstraintsPlugin(constraints))))
end

@testitem "A complex hierarchical constraints with lots of renaming and interleaving with constants" begin
    using Distributions
    using BitSetTuples
    import GraphPPL:
        create_model, with_plugins, PluginsCollection, VariationalConstraintsPlugin, getorcreate!, NodeCreationOptions, hasextra, getextra

    include("../../testutils.jl")

    @model function submodel_3_1(b, n, m)
        b ~ Normal(n, m)
    end

    @model function submodel_3_2(b, n, m)
        b ~ Normal(n + 1, m + 1)
    end

    @model function submodel_2_1(a, b, c, submodel_3)
        c ~ submodel_3(b = a, m = b)
    end

    @model function submodel_2_2(a, b, c, submodel_3)
        c ~ submodel_3(b = a + 1, m = b + 1)
    end

    @model function submodel_1_1(x, y, z, submodel_2, submodel_3)
        z ~ submodel_2(a = x, b = y, submodel_3 = submodel_3)
    end

    @model function submodel_1_2(x, y, z, submodel_2, submodel_3)
        z ~ submodel_2(a = x + 1, b = y + 1, submodel_3 = submodel_3)
    end

    @model function main_model(case, submodel_1, submodel_2, submodel_3)
        r ~ Gamma(1, 1)
        u ~ Beta(1, 1)
        # In the test we impose the mean-field factorization
        # So the exact model structure is not really important 
        # and the result should be the same for all cases
        if case === 1
            o ~ submodel_1(y = r, z = u, submodel_2 = submodel_2, submodel_3 = submodel_3)
        elseif case === 2
            o ~ submodel_1(y = r, x = u, submodel_2 = submodel_2, submodel_3 = submodel_3)
        elseif case === 3
            o ~ submodel_1(x = r, z = u, submodel_2 = submodel_2, submodel_3 = submodel_3)
        end
    end

    constraints_1 = @constraints begin
        q(o, u, r) = q(o)q(u)q(r)
    end

    constraints_2 = @constraints begin
        q(o, u, r) = q(u)q(o)q(r)
    end

    constraints_3 = @constraints begin
        q(r, o, u) = q(u)q(o)q(r)
    end

    constraints = [constraints_1, constraints_2, constraints_3]

    for constraint in constraints,
        case in [1, 2, 3],
        submodel_1 in [submodel_1_1, submodel_1_2],
        submodel_2 in [submodel_2_1, submodel_2_2],
        submodel_3 in [submodel_3_1, submodel_3_2]

        model = create_model(
            with_plugins(
                main_model(case = case, submodel_1 = submodel_1, submodel_2 = submodel_2, submodel_3 = submodel_3),
                PluginsCollection(VariationalConstraintsPlugin(constraint))
            )
        )

        # Gamma and Beta are factorized as well because they use the constants
        @test all(filter(as_node(Normal) | as_node(Gamma) | as_node(Beta), model)) do node
            interfaces = GraphPPL.edges(model, node)
            @test hasextra(model[node], :factorization_constraint_indices)
            return Tuple.(getextra(model[node], :factorization_constraint_indices)) === (map(i -> (i,), 1:length(interfaces))...,)
        end
    end

    # Double check for the full factorization to make sure that the mean-field was not the default one
    for case in [1, 2, 3],
        submodel_1 in [submodel_1_1, submodel_1_2],
        submodel_2 in [submodel_2_1, submodel_2_2],
        submodel_3 in [submodel_3_1, submodel_3_2]

        model = create_model(
            with_plugins(
                main_model(case = case, submodel_1 = submodel_1, submodel_2 = submodel_2, submodel_3 = submodel_3),
                PluginsCollection(VariationalConstraintsPlugin())
            )
        )

        # Gamma and Beta are factorized as well because they use the constants
        @test all(filter(as_node(Gamma) | as_node(Beta), model)) do node
            interfaces = GraphPPL.edges(model, node)
            @test hasextra(model[node], :factorization_constraint_indices)
            return Tuple.(getextra(model[node], :factorization_constraint_indices)) === (map(i -> (i,), 1:length(interfaces))...,)
        end

        # Normal here should use full joint here as no constraints were passed in the constructor
        @test all(filter(as_node(Normal), model)) do node
            interfaces = GraphPPL.edges(model, node)
            @test hasextra(model[node], :factorization_constraint_indices)
            return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1, 2, 3),)
        end
    end
end

@testitem "A joint constraint over 'initial variable' and 'state variables' aka `q(x0, x)q(γ)`" begin
    using Distributions

    import GraphPPL:
        create_model,
        with_plugins,
        PluginsCollection,
        VariationalConstraintsPlugin,
        getorcreate!,
        NodeCreationOptions,
        LazyIndex,
        getextra,
        hasextra

    include("../../testutils.jl")

    @model function some_state_space_model(y)
        γ ~ Gamma(1, 1)
        θ ~ Gamma(1, 1)
        μ0 ~ Beta(1, 1)
        x0 ~ Normal(μ0, γ)
        x_prev = x0
        for i in eachindex(y)
            x[i] ~ Normal(x_prev, γ)
            y[i] ~ Normal(x[i], θ)
        end
    end

    constraints1 = @constraints begin
        q(x0, μ0, x, γ, θ, y) = q(x0, μ0, x, y)q(γ)q(θ)
    end

    constraints2 = @constraints begin
        q(x0, μ0, x, γ, θ, y) = q(γ)q(x0, μ0, x, y)q(θ)
    end

    constraints3 = @constraints begin
        q(x0, μ0, x, γ, θ, y) = q(γ)q(θ)q(x0, μ0, x, y)
    end

    ydata = rand(10)

    for constraints in [constraints1, constraints2, constraints3]
        model = create_model(
            with_plugins(some_state_space_model(), PluginsCollection(VariationalConstraintsPlugin(constraints)))
        ) do model, context
            return (; y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = false), :y, LazyIndex(ydata)))
        end

        @test length(collect(filter(as_node(Normal), model))) == 21
        @test length(collect(filter(as_node(Gamma), model))) == 2

        # Normal here should use structured factorization here
        @test all(filter(as_node(Normal), model)) do node
            neighbors = map(label -> GraphPPL.getname(label), GraphPPL.neighbors(model, node))
            @test hasextra(model[node], :factorization_constraint_indices)
            # Even though `y` is a data variable, it is not factorized at the construction with `factorized = false`
            return Tuple.(getextra(model[node], :factorization_constraint_indices)) === ((1, 2), (3,))
        end
    end
end

@testitem "Apply MeanField constraints" begin
    using GraphPPL
    import GraphPPL: create_model, with_plugins, getproperties, neighbor_data

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    for model_fform in ModelsInTheZooWithoutArguments
        model = create_model(with_plugins(model_fform(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(MeanField()))))
        for node in filter(as_node(), model)
            node_data = model[node]
            @test GraphPPL.getextra(node_data, :factorization_constraint_indices) ==
                Tuple([[i] for i in 1:(length(neighbor_data(getproperties(node_data))))])
        end
    end
end

@testitem "Apply BetheFactorization constraints" begin
    using GraphPPL
    import GraphPPL: create_model, with_plugins, getproperties, neighbor_data, is_factorized

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    # BetheFactorization uses `default_constraints` for `contains_default_constraints`
    # So it is not tested here
    for model_fform in setdiff(Set(ModelsInTheZooWithoutArguments), Set([ contains_default_constraints ]))
        model = create_model(
            with_plugins(model_fform(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin(BetheFactorization())))
        )
        for node in filter(as_node(), model)
            node_data = model[node]
            neighbors_data = neighbor_data(getproperties(node_data))
            factorized_neighbors = is_factorized.(neighbors_data)
            new_constraint = [findall(!, factorized_neighbors)]
            for j in findall(factorized_neighbors)
                push!(new_constraint, [j])
            end
            sort!(new_constraint, by = first)
            @test GraphPPL.getextra(node_data, :factorization_constraint_indices) == Tuple(new_constraint)
        end
    end
end