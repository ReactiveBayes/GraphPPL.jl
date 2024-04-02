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
end

@testitem "DefaultBackend for submodels" begin
    import GraphPPL:
        @model,
        DefaultBackend,
        NodeBehaviour,
        Stochastic,
        Deterministic,
        NodeType,
        Atomic,
        Composite,
        interfaces,
        StaticInterfaces,
        interface_aliases,
        StaticInterfaceAliases

    @model function submodel(y, x, z)
        y ~ Normal(x, z)
    end

    @model function submodel(y, x, z, d)
        y ~ Normal(x, z + d)
    end

    @test NodeType(DefaultBackend(), submodel) == Composite()
    @test NodeBehaviour(DefaultBackend(), submodel) == Stochastic()
    @test interfaces(DefaultBackend(), submodel, GraphPPL.StaticInt(3)) == StaticInterfaces((:y, :x, :z))
    @test interfaces(DefaultBackend(), submodel, GraphPPL.StaticInt(4)) == StaticInterfaces((:y, :x, :z, :d))
    @test interface_aliases(DefaultBackend(), submodel) == StaticInterfaceAliases(())
end