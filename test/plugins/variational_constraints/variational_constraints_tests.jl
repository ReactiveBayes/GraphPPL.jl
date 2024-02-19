@testitem "Empty constraints" begin
    import GraphPPL: VariationalConstraintsPlugin, EmptyConstraints

    @test VariationalConstraintsPlugin() == VariationalConstraintsPlugin(EmptyConstraints)
    @test VariationalConstraintsPlugin(nothing) == VariationalConstraintsPlugin(EmptyConstraints)
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
        VariationalConstraintsPlugin

    include("../../model_zoo.jl")

    @model function simple_model(a, b, c)
        x ~ Gamma(α = b, θ = sqrt(c))
        a ~ Normal(μ = x, τ = 1)
    end

    # Here we don't even need to specify anything, because 
    # everything should be factorized out by default

    constraints = @constraints begin end

    # `nothing` here will create a `datavar`
    for a in (nothing,), b in (nothing, 1, 1.0), c in (nothing, 1, 1.0)
        model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
        context = getcontext(model)

        a = something(a, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :a, nothing))
        b = something(b, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :b, nothing))
        c = something(c, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :c, nothing))

        add_toplevel_model!(model, simple_model, (a = a, b = b, c = c))

        @test all(filter(as_node(Gamma) | as_node(Normal), model)) do node
            interfaces = GraphPPL.edges(model, node)
            @test hasextra(model[node], :factorization_constraint)
            return getextra(model[node], :factorization_constraint) === (map(interface -> (interface,), interfaces)...,)
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
        VariationalConstraintsPlugin

    include("../../model_zoo.jl")

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
            model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
            context = getcontext(model)
            y = nothing

            for i in 1:n
                y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, i)
            end

            add_toplevel_model!(model, random_walk, (y = y, a = 1, b = 2))

            @test length(collect(filter(as_node(Normal), model))) === 2 * n
            @test length(collect(filter(as_node(NormalMeanVariance), model))) === n + 1
            @test length(collect(filter(as_node(NormalMeanPrecision), model))) === n - 1
            @test length(collect(filter(as_node(prod), model))) === n - 1
            @test length(collect(filter(as_node(sum), model))) === n - 1

            @test all(filter(as_node(NormalMeanVariance), model)) do node
                # This must be factorized out just because of the implicit constraint for conststs and datavars
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint)
                return getextra(model[node], :factorization_constraint) === ((interfaces[1],), (interfaces[2],), (interfaces[3],))
            end

            @test all(filter(as_node(NormalMeanPrecision), model)) do node
                # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
                # is correctly resolved to structured, since empty constraints do not factorize out this case
                interfaces = GraphPPL.edges(model, node)
                @test hasextra(model[node], :factorization_constraint)
                return getextra(model[node], :factorization_constraint) === ((interfaces[1], interfaces[2]), (interfaces[3],))
            end
        end

        @testset let constraints = mean_field_constraints
            model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
            context = getcontext(model)
            y = nothing

            for i in 1:n
                y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, i)
            end

            add_toplevel_model!(model, random_walk, (y = y, a = 1, b = 2))

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
                @test hasextra(model[node], :factorization_constraint)
                return getextra(model[node], :factorization_constraint) === ((interfaces[1],), (interfaces[2],), (interfaces[3],))
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
        VariationalConstraintsPlugin

    include("../../model_zoo.jl")

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
        model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
        context = getcontext(model)

        a = something(a, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :a, nothing))
        b = something(b, getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :b, nothing))

        y = nothing
        for i in 1:n
            y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, i)
        end

        add_toplevel_model!(model, context, simple_model, (a = a, b = b, y = y))

        @test length(collect(filter(as_node(MvNormal), model))) === n - 1

        @test all(filter(as_node(MvNormal), model)) do node
            @test hasextra(model[node], :factorization_constraint)
            interfaces = GraphPPL.interfaces(MvNormal, static(3))
            # desired constraints 
            desired = Set([(interfaces[1], interfaces[2]), (interfaces[3],)])
            # actual constraints 
            actual = Set(map(cluster -> GraphPPL.getname.(cluster), getextra(model[node], :factorization_constraint)))
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
        VariationalConstraintsPlugin

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
        model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
        context = getcontext(model)
        y = nothing

        for i in 1:n
            y = getorcreate!(model, context, NodeCreationOptions(kind = :data, factorized = true), :y, i)
        end

        add_toplevel_model!(model, context, random_walk, (y = y, a = 1, b = 2))

        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_node(prod), model))) === n - 1
        @test length(collect(filter(as_node(sum), model))) === n - 1

        @test all(filter(as_node(Normal), model)) do gnode
            @test hasextra(model[gnode], :factorization_constraint)
            # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
            # is correctly resolved to mean-field, because `a * x[i - 1] + b` is deterministically linked to `x[i - 1]`, thus 
            # the interfaces must be factorized out
            # Note that in this particular test we simply test all Gaussian nodes because 
            # other Gaussians are also mean-field due to other (implicit) constraints
            interfaces = GraphPPL.edges(model, gnode)
            return getextra(model[gnode], :factorization_constraint) === ((interfaces[1],), (interfaces[2],), (interfaces[3],))
        end
    end
end

@testitem "Simple @model + functional form constraints" begin
    using Distributions

    import GraphPPL:
        create_model, add_toplevel_model!, variable_nodes, getextra, hasextra, as_variable, PluginsCollection, VariationalConstraintsPlugin

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

        model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_posterior)))

        add_toplevel_model!(model, simple_model_for_fform_constraints, NamedTuple())

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

        model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_messages)))

        add_toplevel_model!(model, simple_model_for_fform_constraints, NamedTuple())

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

        model = create_model(plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_both)))

        add_toplevel_model!(model, simple_model_for_fform_constraints, NamedTuple())

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
    import GraphPPL: apply!, PluginsCollection, VariationalConstraintsPlugin, getname, getextra, hasextra

    include("../../model_zoo.jl")

    constraints = @constraints begin
        q(x, y) = q(x)q(y)
        q(y, z) = q(y)q(z)
        q(x)::NormalMeanVariance()
        μ(y)::NormalMeanVariance()
    end
    # Test constraints macro with single variables and no nesting
    model = create_terminated_model(simple_model; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
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
    @test getname(getextra(model[ctx[NormalMeanVariance, 1]], :factorization_constraint)) == ((:out,), (:μ,), (:σ,))
    @test getname(getextra(model[ctx[NormalMeanVariance, 2]], :factorization_constraint)) == ((:out, :μ), (:σ,))

    # Test constriants macro with nested model
    constraints = @constraints begin
        for q in inner
            q(α, θ) = q(α)q(θ)
            q(α)::NormalMeanVariance()
            μ(θ)::NormalMeanVariance()
        end
    end
    model = create_terminated_model(outer; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
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
        @test getname(getextra(model[node], :factorization_constraint)) == ((:out,), (:μ, :σ))
    end

    # Test with specifying specific submodel
    constraints = @constraints begin
        for q in (child_model, 1)
            q(in, out, σ) = q(in, out)q(σ)
        end
    end
    model = create_terminated_model(parent_model; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
    ctx = GraphPPL.getcontext(model)

    @test getname(getextra(model[ctx[child_model, 1][NormalMeanVariance, 1]], :factorization_constraint)) == ((:out, :μ), (:σ,))
    for i in 2:99
        @test getname(getextra(model[ctx[child_model, i][NormalMeanVariance, 1]], :factorization_constraint)) == ((:out, :μ, :σ),)
    end

    # Test with specifying general submodel
    constraints = @constraints begin
        for q in child_model
            q(in, out, σ) = q(in, out)q(σ)
        end
    end
    model = create_terminated_model(parent_model; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints)))
    ctx = GraphPPL.getcontext(model)

    @test getname(getextra(model[ctx[child_model, 1][NormalMeanVariance, 1]], :factorization_constraint)) == ((:out, :μ), (:σ,))
    for node in filter(GraphPPL.as_node(NormalMeanVariance) & GraphPPL.as_context(child_model), model)
        @test getname(getextra(model[node], :factorization_constraint)) == ((:out, :μ), (:σ,))
    end

    # Test with ambiguous constraints
    constraints = @constraints begin
        q(x, y) = q(x)q(y)
    end
    @test_throws ErrorException create_terminated_model(
        simple_model; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints))
    )
end
