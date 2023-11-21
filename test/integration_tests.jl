@testitem "simple @model + mean field @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions
    using GraphPPL: create_model, getcontext, getorcreate!, add_terminated_submodel!, apply!, as_node, factorization_constraint, VariableNodeOptions

    include("./model_zoo.jl")

    @model function simple_model(a, b, c)
        x ~ Gamma(α=b, θ=sqrt(c))
        a ~ Normal(μ=x, τ=1)
    end

    # Here we don't even need to specify anything, because 
    # everything should be factorized out by default

    constraints = @constraints begin end

    # `nothing` here will create a `datavar`
    for a in (nothing,), b in (nothing, 1, 1.0), c in (nothing, 1, 1.0)
        model = create_model()
        context = getcontext(model)

        a = something(a, getorcreate!(model, context, :a, nothing, options=VariableNodeOptions(datavar=true, factorized=true)))
        b = something(b, getorcreate!(model, context, :b, nothing, options=VariableNodeOptions(datavar=true, factorized=true)))
        c = something(c, getorcreate!(model, context, :c, nothing, options=VariableNodeOptions(datavar=true, factorized=true)))

        add_terminated_submodel!(model, context, simple_model, (a=a, b=b, c=c))
        apply!(model, constraints)

        @test all(filter(as_node(Gamma) | as_node(Normal), model)) do node
            interfaces = GraphPPL.edges(model, node)
            return factorization_constraint(model[node]) === (map(interface -> (interface,), interfaces)...,)
        end
    end
end

@testitem "state space model @model + mean field @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions
    using GraphPPL: create_model, getcontext, getorcreate!, add_terminated_submodel!, apply!, as_node, factorization_constraint, VariableNodeOptions

    include("./model_zoo.jl")

    @model function random_walk(y, a, b)
        x[1] ~ NormalMeanVariance(0, 1)
        y[1] ~ NormalMeanVariance(x[1], 1)

        for i in 2:length(y)
            x[i] ~ NormalMeanPrecision(a * x[i-1] + b, 1)
            y[i] ~ NormalMeanVariance(x[i], 1)
        end
    end

    empty_constraints = @constraints begin end

    mean_field_constraints = @constraints begin
        q(x) = q(x[begin]) .. q(x[end])
    end

    @testset for n in 1:5
        @testset let constraints = empty_constraints
            model = create_model()
            context = getcontext(model)
            y = nothing

            for i in 1:n
                y = getorcreate!(model, context, :y, i, options=VariableNodeOptions(datavar=true, factorized=true))
            end

            add_terminated_submodel!(model, context, random_walk, (y=y, a=1, b=2))

            @test length(collect(filter(as_node(Normal), model))) === 2 * n
            @test length(collect(filter(as_node(NormalMeanVariance), model))) === n + 1
            @test length(collect(filter(as_node(NormalMeanPrecision), model))) === n - 1
            @test length(collect(filter(as_node(prod), model))) === n - 1
            @test length(collect(filter(as_node(sum), model))) === n - 1

            apply!(model, constraints)

            @test all(filter(as_node(NormalMeanVariance), model)) do node
                # This must be factorized out just because of the implicit constraint for conststs and datavars
                interfaces = GraphPPL.edges(model, node)
                return factorization_constraint(model[node]) === ((interfaces[1],), (interfaces[2],), (interfaces[3],))
            end

            @test all(filter(as_node(NormalMeanPrecision), model)) do node
                # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
                # is correctly resolved to structured, since empty constraints do not factorize out this case
                interfaces = GraphPPL.edges(model, node)
                return factorization_constraint(model[node]) === ((interfaces[1], interfaces[2],), (interfaces[3],))
            end
        end

        @testset let constraints = mean_field_constraints
            model = create_model()
            context = getcontext(model)
            y = nothing

            for i in 1:n
                y = getorcreate!(model, context, :y, i, options=VariableNodeOptions(datavar=true, factorized=true))
            end

            add_terminated_submodel!(model, context, random_walk, (y=y, a=1, b=2))

            @test length(collect(filter(as_node(Normal), model))) == 2 * n
            @test length(collect(filter(as_node(NormalMeanVariance), model))) === n + 1
            @test length(collect(filter(as_node(NormalMeanPrecision), model))) === n - 1
            @test length(collect(filter(as_node(prod), model))) === n - 1
            @test length(collect(filter(as_node(sum), model))) === n - 1

            apply!(model, constraints)

            @test all(filter(as_node(NormalMeanPrecision) | as_node(NormalMeanVariance), model)) do node
                # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
                # is correctly resolved to mean-field, because `a * x[i - 1] + b` is deterministically linked to `x[i - 1]`, thus 
                # the interfaces must be factorized out
                # The reset are factorized out just because of the implicit constraint for conststs and datavars
                interfaces = GraphPPL.edges(model, node)
                return factorization_constraint(model[node]) === ((interfaces[1],), (interfaces[2],), (interfaces[3],))
            end
        end
    end
end

@testitem "simple @model + structured @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions, LinearAlgebra
    using GraphPPL: create_model, getcontext, getorcreate!, add_terminated_submodel!, apply!, as_node, factorization_constraint, VariableNodeOptions

    include("./model_zoo.jl")

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
        model = create_model()
        context = getcontext(model)

        a = something(a, getorcreate!(model, context, :a, nothing, options=VariableNodeOptions(datavar=true, factorized=true)))
        b = something(b, getorcreate!(model, context, :b, nothing, options=VariableNodeOptions(datavar=true, factorized=true)))
        
        y = nothing
        for i in 1:n
            y = getorcreate!(model, context, :y, i, options=VariableNodeOptions(datavar=true, factorized=true))
        end

        add_terminated_submodel!(model, context, simple_model, (a=a, b=b, y=y))
        apply!(model, constraints)

        @test length(collect(filter(as_node(MvNormal), model))) === n - 1

        @test all(filter(as_node(MvNormal), model)) do node
            interfaces = GraphPPL.interfaces(MvNormal, static(3))
            # desired constraints 
            desired = Set([ (interfaces[1], interfaces[2]), (interfaces[3], ) ])
            # actual constraints 
            actual = Set(map(cluster -> GraphPPL.getname.(cluster), factorization_constraint(model[node])))
            return isequal(desired, actual)
        end
    end
end

@testitem "state space @model (nested) + @constraints + anonymous variable linked through a deterministic relation" begin
    using Distributions
    using GraphPPL: create_model, getcontext, getorcreate!, add_terminated_submodel!, apply!, as_node, factorization_constraint, VariableNodeOptions

    @model function nested2(u, θ, c, d)
        u ~ Normal(c * θ + d, 1)
    end

    @model function nested1(z, g, a, b)
        z ~ nested2(θ=g, c=a, d=b)
    end

    @model function random_walk(y, a, b)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)

        for i in 2:length(y)
            x[i] ~ nested1(g=x[i-1], a=a, b=b)
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

        model = create_model()
        context = getcontext(model)
        y = nothing

        for i in 1:n
            y = getorcreate!(model, context, :y, i, options=VariableNodeOptions(datavar=true, factorized=true))
        end

        add_terminated_submodel!(model, context, random_walk, (y=y, a=1, b=2))
        apply!(model, constraints)

        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_node(prod), model))) === n - 1
        @test length(collect(filter(as_node(sum), model))) === n - 1

        @test all(filter(as_node(Normal), model)) do gnode
            # The test tests that the factorization constraint around the node `x[i] ~ Normal(a * x[i - 1] + b, 1)`
            # is correctly resolved to mean-field, because `a * x[i - 1] + b` is deterministically linked to `x[i - 1]`, thus 
            # the interfaces must be factorized out
            # Note that in this particular test we simply test all Gaussian nodes because 
            # other Gaussians are also mean-field due to other (implicit) constraints
            interfaces = GraphPPL.edges(model, gnode)
            return factorization_constraint(model[gnode]) === ((interfaces[1],), (interfaces[2],), (interfaces[3],))
        end
    end
end