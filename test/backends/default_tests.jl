@testitem "Instantiation" begin
    import GraphPPL: DefaultBackend, instantiate

    @test instantiate(DefaultBackend) == DefaultBackend()
end

@testitem "NodeBehaviour" begin
    using Distributions
    import GraphPPL: DefaultBackend, NodeBehaviour, Stochastic, Deterministic

    include("../testutils.jl")

    using .TestUtils.ModelZoo

    # The `DefaultBackend` defines `Stochastic` behaviour for objects from the `Distributions` module
    @test NodeBehaviour(DefaultBackend(), Normal) == Stochastic()
    @test NodeBehaviour(DefaultBackend(), Gamma) == Stochastic()

    # By default all Julia functions are detereministic
    @test NodeBehaviour(DefaultBackend(), sum) == Deterministic()
    @test NodeBehaviour(DefaultBackend(), prod) == Deterministic()
    @test NodeBehaviour(DefaultBackend(), (x) -> x + 1) == Deterministic()

    # Raw Julia types are also deterministic
    @test NodeBehaviour(DefaultBackend(), Matrix) == Deterministic()
    @test NodeBehaviour(DefaultBackend(), Vector) == Deterministic()

    import GraphPPL: @model

    @model function submodel(y, x, z)
        y ~ Normal(x, z)
    end

    # Composite nodes are defined explicitly in the `@model` macro
    @test NodeBehaviour(DefaultBackend(), submodel) == Stochastic()
end

@testitem "NodeType" begin
    using Distributions
    import GraphPPL: DefaultBackend, NodeType, Atomic, Composite

    # The `DefaultBackend` defines `Atomic` behaviour for objects from the `Distributions` module
    # but also for functions and types
    @test NodeType(DefaultBackend(), Normal) == Atomic()
    @test NodeType(DefaultBackend(), Gamma) == Atomic()
    @test NodeType(DefaultBackend(), Matrix) == Atomic()
    @test NodeType(DefaultBackend(), Vector) == Atomic()

    import GraphPPL: @model

    @model function submodel(y, x, z)
        y ~ Normal(x, z)
    end

    # Composite nodes are defined explicitly in the `@model` macro
    @test NodeType(DefaultBackend(), submodel) == Composite()
end
