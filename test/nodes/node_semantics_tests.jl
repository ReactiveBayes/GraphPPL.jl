@testitem "NodeType" begin
    import GraphPPL: NodeType, Composite, Atomic

    include("testutils.jl")

    using .TestUtils.ModelZoo

    model = create_test_model()

    @test NodeType(model, Composite) == Atomic()
    @test NodeType(model, Atomic) == Atomic()
    @test NodeType(model, abs) == Atomic()
    @test NodeType(model, Normal) == Atomic()
    @test NodeType(model, NormalMeanVariance) == Atomic()
    @test NodeType(model, NormalMeanPrecision) == Atomic()

    # Could test all here 
    for model_fn in ModelsInTheZooWithoutArguments
        @test NodeType(model, model_fn) == Composite()
    end
end

@testitem "NodeBehaviour" begin
    import GraphPPL: NodeBehaviour, Deterministic, Stochastic

    include("testutils.jl")

    using .TestUtils.ModelZoo

    model = create_test_model()

    @test NodeBehaviour(model, () -> 1) == Deterministic()
    @test NodeBehaviour(model, Matrix) == Deterministic()
    @test NodeBehaviour(model, abs) == Deterministic()
    @test NodeBehaviour(model, Normal) == Stochastic()
    @test NodeBehaviour(model, NormalMeanVariance) == Stochastic()
    @test NodeBehaviour(model, NormalMeanPrecision) == Stochastic()

    # Could test all here 
    for model_fn in ModelsInTheZooWithoutArguments
        @test NodeBehaviour(model, model_fn) == Stochastic()
    end
end

@testitem "interface_alias" begin
    using GraphPPL
    import GraphPPL: interface_aliases, StaticInterfaces

    include("testutils.jl")

    model = create_test_model()

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

@testitem "factor_alias" begin
    import GraphPPL: factor_alias, StaticInterfaces

    include("testutils.jl")

    function abc end
    function xyz end

    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(abc), ::StaticInterfaces{(:a, :b)}) = abc
    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(abc), ::StaticInterfaces{(:x, :y)}) = xyz

    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(xyz), ::StaticInterfaces{(:a, :b)}) = abc
    GraphPPL.factor_alias(::TestUtils.TestGraphPPLBackend, ::typeof(xyz), ::StaticInterfaces{(:x, :y)}) = xyz

    model = create_test_model()

    @test factor_alias(model, abc, StaticInterfaces((:a, :b))) === abc
    @test factor_alias(model, abc, StaticInterfaces((:x, :y))) === xyz

    @test factor_alias(model, xyz, StaticInterfaces((:a, :b))) === abc
    @test factor_alias(model, xyz, StaticInterfaces((:x, :y))) === xyz
end

@testitem "default_parametrization" begin
    import GraphPPL: default_parametrization, Composite, Atomic

    include("testutils.jl")

    using .TestUtils.ModelZoo

    model = create_test_model()

    # Test 1: Add default arguments to Normal call
    @test default_parametrization(model, Atomic(), Normal, (0, 1)) == (μ = 0, σ = 1)

    # Test 2: Add :in to function call that has default behaviour 
    @test default_parametrization(model, Atomic(), +, (1, 2)) == (in = (1, 2),)

    # Test 3: Add :in to function call that has default behaviour with nested interfaces
    @test default_parametrization(model, Atomic(), +, ([1, 1], 2)) == (in = ([1, 1], 2),)

    @test_throws ErrorException default_parametrization(model, Composite(), gcv, (1, 2))
end

@testitem "getindex for StaticInterfaces" begin
    import GraphPPL: StaticInterfaces

    interfaces = (:a, :b, :c)
    sinterfaces = StaticInterfaces(interfaces)

    for (i, interface) in enumerate(interfaces)
        @test sinterfaces[i] === interface
    end
end

@testitem "missing_interfaces" begin
    import GraphPPL: missing_interfaces, interfaces

    include("testutils.jl")

    model = create_test_model()

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

@testitem "sort_interfaces" begin
    import GraphPPL: sort_interfaces

    include("testutils.jl")

    model = create_test_model()

    # Test 1: Test that sort_interfaces sorts the interfaces in the correct order
    @test sort_interfaces(model, NormalMeanVariance, (μ = 1, σ = 1, out = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, NormalMeanVariance, (out = 1, μ = 1, σ = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, NormalMeanVariance, (σ = 1, out = 1, μ = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, NormalMeanVariance, (σ = 1, μ = 1, out = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(model, NormalMeanPrecision, (μ = 1, τ = 1, out = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(model, NormalMeanPrecision, (out = 1, μ = 1, τ = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(model, NormalMeanPrecision, (τ = 1, out = 1, μ = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(model, NormalMeanPrecision, (τ = 1, μ = 1, out = 1)) == (out = 1, μ = 1, τ = 1)

    @test_throws ErrorException sort_interfaces(model, NormalMeanVariance, (σ = 1, μ = 1, τ = 1))
end

@testitem "prepare_interfaces" begin
    import GraphPPL: prepare_interfaces

    include("testutils.jl")

    using .TestUtils.ModelZoo

    model = create_test_model()

    @test prepare_interfaces(model, anonymous_in_loop, 1, (y = 1,)) == (x = 1, y = 1)
    @test prepare_interfaces(model, anonymous_in_loop, 1, (x = 1,)) == (y = 1, x = 1)

    @test prepare_interfaces(model, type_arguments, 1, (x = 1,)) == (n = 1, x = 1)
    @test prepare_interfaces(model, type_arguments, 1, (n = 1,)) == (x = 1, n = 1)
end