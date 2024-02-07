@testitem "Graph construction" begin
    using GraphPPL
    using Distributions

    function create_terminated_model(fform; interfaces = NamedTuple())
        __model__ = GraphPPL.create_model(; fform = fform)
        __context__ = GraphPPL.getcontext(__model__)
        GraphPPL.add_terminated_submodel!(__model__, __context__, fform, interfaces; __parent_options__ = GraphPPL.FactorNodeOptions())
        return __model__
    end

    # Test that graph construction creates the right amount of nodes and variables in a simple state space model
    @model function state_space_model(n)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:n
            x[i] ~ Normal(x[i - 1], 1)
            y[i] ~ Normal(x[i], 1)
        end
    end
    for n in [10, 30, 50, 100, 1000]
        model = create_terminated_model(state_space_model, interfaces = (n = n,))
        @test length(collect(filter(as_node(Normal), model))) == 2 * n
        @test length(collect(filter(as_variable(:x), model))) == n
        @test length(collect(filter(as_variable(:y), model))) == n
    end


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
            x_3[i] ~ Normal(μ = x_3[i - 1], τ = ξ)
            x_2[i] ~ gcv(x = x_2[i - 1], z = x_3[i], ω = ω_2, κ = κ_2)
            x_1[i] ~ gcv_lm(x_prev = x_1[i - 1], z = x_2[i], ω = ω_1, κ = κ_1, y = y[i - 1])
        end
    end

    for n in [10, 30, 50, 100, 1000]
        model = GraphPPL.create_model()
        context = GraphPPL.getcontext(model)
        for i in 1:n
            GraphPPL.getorcreate!(model, context, :y, i)
        end 
        GraphPPL.add_terminated_submodel!(model, context, hgf, (y = GraphPPL.getorcreate!(model, context, :y, 1), ))
        @test length(collect(filter(as_node(Normal), model))) == (4 * n) + 7
        @test length(collect(filter(as_node(Gamma), model))) == 1
        @test length(collect(filter(as_node(Normal) & as_context(gcv), model))) == 2 * n 
        @test length(collect(filter(as_variable(:x_1), model))) == n + 1
    end
end