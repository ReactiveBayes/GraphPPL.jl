@testitem "IndexedVariable" begin
    import GraphPPL: IndexedVariable, CombinedRange, SplittedRange, getname, index

    # Test 1: Test IndexedVariable
    @test IndexedVariable(:x, nothing) isa IndexedVariable

    # Test 2: Test IndexedVariable equality
    lhs = IndexedVariable(:x, nothing)
    rhs = IndexedVariable(:x, nothing)
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:y, nothing)
    @test lhs !== IndexedVariable(:y, nothing)
    @test getname(IndexedVariable(:x, nothing)) === :x
    @test getname(IndexedVariable(:x, 1)) === :x
    @test getname(IndexedVariable(:y, nothing)) === :y
    @test getname(IndexedVariable(:y, 1)) === :y
    @test index(IndexedVariable(:x, nothing)) === nothing
    @test index(IndexedVariable(:x, 1)) === 1
    @test index(IndexedVariable(:y, nothing)) === nothing
    @test index(IndexedVariable(:y, 1)) === 1
end

@testitem "FunctionalIndex" begin
    import GraphPPL: FunctionalIndex

    collection = [1, 2, 3, 4, 5]

    # Test 1: Test FunctionalIndex{:begin}
    index = FunctionalIndex{:begin}(firstindex)
    @test index(collection) === firstindex(collection)

    # Test 2: Test FunctionalIndex{:end}
    index = FunctionalIndex{:end}(lastindex)
    @test index(collection) === lastindex(collection)

    # Test 3: Test FunctionalIndex{:begin} + 1
    index = FunctionalIndex{:begin}(firstindex) + 1
    @test index(collection) === firstindex(collection) + 1

    # Test 4: Test FunctionalIndex{:end} - 1
    index = FunctionalIndex{:end}(lastindex) - 1
    @test index(collection) === lastindex(collection) - 1

    # Test 5: Test FunctionalIndex equality
    lhs = FunctionalIndex{:begin}(firstindex)
    rhs = FunctionalIndex{:begin}(firstindex)
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != FunctionalIndex{:end}(lastindex)
    @test lhs !== FunctionalIndex{:end}(lastindex)

    for N in 1:5
        collection = ones(N)
        @test FunctionalIndex{:nothing}(firstindex)(collection) === firstindex(collection)
        @test FunctionalIndex{:nothing}(lastindex)(collection) === lastindex(collection)
        @test (FunctionalIndex{:nothing}(firstindex) + 1)(collection) === firstindex(collection) + 1
        @test (FunctionalIndex{:nothing}(lastindex) - 1)(collection) === lastindex(collection) - 1
        @test (FunctionalIndex{:nothing}(firstindex) + 1 - 2 + 3)(collection) === firstindex(collection) + 1 - 2 + 3
        @test (FunctionalIndex{:nothing}(lastindex) - 1 + 2 - 3)(collection) === lastindex(collection) - 1 + 2 - 3
    end

    @test repr(FunctionalIndex{:begin}(firstindex)) === "(begin)"
    @test repr(FunctionalIndex{:begin}(firstindex) + 1) === "((begin) + 1)"
    @test repr(FunctionalIndex{:begin}(firstindex) - 1) === "((begin) - 1)"
    @test repr(FunctionalIndex{:begin}(firstindex) - 1 + 1) === "(((begin) - 1) + 1)"

    @test repr(FunctionalIndex{:end}(lastindex)) === "(end)"
    @test repr(FunctionalIndex{:end}(lastindex) + 1) === "((end) + 1)"
    @test repr(FunctionalIndex{:end}(lastindex) - 1) === "((end) - 1)"
    @test repr(FunctionalIndex{:end}(lastindex) - 1 + 1) === "(((end) - 1) + 1)"

    @test isbitstype(typeof((FunctionalIndex{:begin}(firstindex) + 1)))
    @test isbitstype(typeof((FunctionalIndex{:begin}(firstindex) - 1)))
    @test isbitstype(typeof((FunctionalIndex{:begin}(firstindex) + 1 + 1)))
    @test isbitstype(typeof((FunctionalIndex{:begin}(firstindex) - 1 + 1)))
end

@testitem "FunctionalRange" begin
    import GraphPPL: FunctionalIndex

    collection = [1, 2, 3, 4, 5]

    range = FunctionalIndex{:begin}(firstindex):FunctionalIndex{:end}(lastindex)
    @test collection[range] == collection

    range = (FunctionalIndex{:begin}(firstindex) + 1):(FunctionalIndex{:end}(lastindex) - 1)
    @test collection[range] == collection[(begin + 1):(end - 1)]

    for i in 1:length(collection)
        _range = i:FunctionalIndex{:end}(lastindex)
        @test collection[_range] == collection[i:end]
    end

    for i in 1:length(collection)
        _range = FunctionalIndex{:begin}(firstindex):i
        @test collection[_range] == collection[begin:i]
    end
end

@testitem "Lift index" begin
    import GraphPPL: lift_index, True, False, checked_getindex

    @test lift_index(True(), nothing, nothing) === nothing
    @test lift_index(True(), (1,), nothing) === (1,)
    @test lift_index(True(), nothing, (1,)) === (1,)
    @test lift_index(True(), (2,), (1,)) === (2,)
    @test lift_index(True(), (2, 2), (1,)) === (2, 2)

    @test lift_index(False(), nothing, nothing) === nothing
    @test lift_index(False(), (1,), nothing) === nothing
    @test lift_index(False(), nothing, (1,)) === (1,)
    @test lift_index(False(), (2,), (1,)) === (1,)
    @test lift_index(False(), (2, 2), (1,)) === (1,)

    import GraphPPL: proxylabel, lift_index, unroll, ProxyLabel

    struct LiftingTest end

    GraphPPL.is_proxied(::Type{LiftingTest}) = GraphPPL.True()

    function GraphPPL.unroll(proxy::ProxyLabel, ::LiftingTest, index, maycreate, liftedindex)
        if liftedindex === nothing
            return checked_getindex("Hello", index)
        else
            return checked_getindex("World", index)
        end
    end

    @test unroll(proxylabel(:x, LiftingTest(), nothing, True())) === "Hello"
    @test unroll(proxylabel(:x, LiftingTest(), (1,), True())) === 'W'
    @test unroll(proxylabel(:r, proxylabel(:x, proxylabel(:z, LiftingTest(), nothing), (3,), True()), nothing)) === 'r'
    @test unroll(
        proxylabel(:r, proxylabel(:x, proxylabel(:w, proxylabel(:z, LiftingTest(), nothing), (2:3,), True()), (1,), False()), nothing)
    ) === 'o'
end

@testitem "`VariableRef` iterators interface" begin
    import GraphPPL: VariableRef, getcontext, NodeCreationOptions, VariableKindData, getorcreate!

    include("testutils.jl")

    @testset "Missing internal and external collections" begin
        model = create_test_model()
        ctx = getcontext(model)
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))

        @test @inferred(Base.IteratorSize(xref)) === Base.SizeUnknown()
        @test @inferred(Base.IteratorEltype(xref)) === Base.EltypeUnknown()
        @test @inferred(Base.eltype(xref)) === Any
    end

    @testset "Existing internal and external collections" begin
        model = create_test_model()
        ctx = getcontext(model)
        xcollection = getorcreate!(model, ctx, NodeCreationOptions(), :x, 1)
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (1,), xcollection)

        @test @inferred(Base.IteratorSize(xref)) === Base.HasShape{1}()
        @test @inferred(Base.IteratorEltype(xref)) === Base.HasEltype()
        @test @inferred(Base.eltype(xref)) === GraphPPL.NodeLabel
    end

    @testset "Missing internal but existing external collections" begin
        model = create_test_model()
        ctx = getcontext(model)
        xref = VariableRef(model, ctx, NodeCreationOptions(kind = VariableKindData), :x, (nothing,), [1.0 1.0; 1.0 1.0])

        @test @inferred(Base.IteratorSize(xref)) === Base.HasShape{2}()
        @test @inferred(Base.IteratorEltype(xref)) === Base.HasEltype()
        @test @inferred(Base.eltype(xref)) === Float64
    end
end

@testitem "`VariableRef` in combination with `ProxyLabel` should create variables in the model" begin
    import GraphPPL:
        VariableRef,
        makevarref,
        getcontext,
        getifcreated,
        unroll,
        set_maycreate,
        ProxyLabel,
        NodeLabel,
        proxylabel,
        NodeCreationOptions,
        VariableKindRandom,
        VariableKindData,
        getproperties,
        is_kind,
        MissingCollection,
        getorcreate!

    using Distributions

    include("testutils.jl")

    @testset "Individual variable creation" begin
        model = create_test_model()
        ctx = getcontext(model)
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
        @test_throws "The variable `x` has been used, but has not been instantiated." getifcreated(model, ctx, xref)
        x = unroll(proxylabel(:p, xref, nothing, True()))
        @test x isa NodeLabel
        @test x === ctx[:x]
        @test is_kind(getproperties(model[x]), VariableKindRandom)
        @test getifcreated(model, ctx, xref) === ctx[:x]

        zref = VariableRef(model, ctx, NodeCreationOptions(kind = VariableKindData), :z, (nothing,), MissingCollection())
        # @test_throws "The variable `z` has been used, but has not been instantiated." getifcreated(model, ctx, zref)
        # The label above SHOULD NOT throw, since it has been instantiated with the `MissingCollection`

        # Top level `False` should not play a role here really, but is also essential
        # The bottom level `True` does allow the creation of the variable and the top-level `False` should only fetch
        z = unroll(proxylabel(:r, proxylabel(:w, zref, nothing, True()), nothing, False()))
        @test z isa NodeLabel
        @test z === ctx[:z]
        @test is_kind(getproperties(model[z]), VariableKindData)
        @test getifcreated(model, ctx, zref) === ctx[:z]
    end

    @testset "Vectored variable creation" begin
        model = create_test_model()
        ctx = getcontext(model)
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
        @test_throws "The variable `x` has been used, but has not been instantiated." getifcreated(model, ctx, xref)
        for i in 1:10
            x = unroll(proxylabel(:x, xref, (i,), True()))
            @test x isa NodeLabel
            @test x === ctx[:x][i]
            @test getifcreated(model, ctx, xref) === ctx[:x]
        end
        @test length(xref) === 10
        @test firstindex(xref) === 1
        @test lastindex(xref) === 10
        @test collect(eachindex(xref)) == collect(1:10)
        @test size(xref) === (10,)
    end

    @testset "Tensor variable creation" begin
        model = create_test_model()
        ctx = getcontext(model)
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
        @test_throws "The variable `x` has been used, but has not been instantiated." getifcreated(model, ctx, xref)
        for i in 1:10, j in 1:10
            xij = unroll(proxylabel(:x, xref, (i, j), True()))
            @test xij isa NodeLabel
            @test xij === ctx[:x][i, j]
            @test getifcreated(model, ctx, xref) === ctx[:x]
        end
        @test length(xref) === 100
        @test firstindex(xref) === 1
        @test lastindex(xref) === 100
        @test collect(eachindex(xref)) == collect(CartesianIndices((1:10, 1:10)))
        @test size(xref) === (10, 10)
    end

    @testset "Variable should not be created if the `creation` flag is set to `False`" begin
        model = create_test_model()
        ctx = getcontext(model)
        # `x` is not created here, should fail during `unroll`
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
        @test_throws "The variable `x` has been used, but has not been instantiated." getifcreated(model, ctx, xref)
        @test_throws "The variable `x` has been used, but has not been instantiated" unroll(proxylabel(:x, xref, nothing, False()))
        # Force create `x`
        getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
        # Since `x` has been created the `False` flag should not throw
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
        @test ctx[:x] === unroll(proxylabel(:x, xref, nothing, False()))
        @test getifcreated(model, ctx, xref) === ctx[:x]
    end

    @testset "Variable should be created if the `Atomic` fform is used as a first argument with `makevarref`" begin
        model = create_test_model()
        ctx = getcontext(model)
        # `x` is not created here, but `makevarref` takes into account the `Atomic/Composite`
        # we always create a variable when used with `Atomic`
        xref = makevarref(Normal, model, ctx, NodeCreationOptions(), :x, (nothing,))
        # `@inferred` here is important for simple use cases like `x ~ Normal(0, 1)`, so 
        # `x` can be inferred properly
        @test ctx[:x] === @inferred(unroll(proxylabel(:x, xref, nothing, False())))
    end

    @testset "It should be possible to toggle `maycreate` flag" begin
        model = create_test_model()
        ctx = getcontext(model)
        xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
        # The first time should throw since the variable has not been instantiated yet
        @test_throws "The variable `x` has been used, but has not been instantiated." unroll(proxylabel(:x, xref, nothing, False()))
        # Even though the `maycreate` flag is set to `True`, the `set_maycreate` should overwrite it with `False`
        @test_throws "The variable `x` has been used, but has not been instantiated." unroll(
            set_maycreate(proxylabel(:x, xref, nothing, True()), False())
        )

        # Even though the `maycreate` flag is set to `False`, the `set_maycreate` should overwrite it with `True`
        @test unroll(set_maycreate(proxylabel(:x, xref, nothing, False()), True())) === ctx[:x]
        # At this point the variable should be created
        @test unroll(proxylabel(:x, xref, nothing, False())) === ctx[:x]
        @test unroll(proxylabel(:x, xref, nothing, True())) === ctx[:x]

        @test set_maycreate(1, True()) === 1
        @test set_maycreate(1, False()) === 1
    end
end

@testitem "`VariableRef` comparison" begin
    import GraphPPL:
        VariableRef,
        makevarref,
        getcontext,
        getifcreated,
        unroll,
        ProxyLabel,
        NodeLabel,
        proxylabel,
        NodeCreationOptions,
        VariableKindRandom,
        VariableKindData,
        getproperties,
        is_kind,
        MissingCollection,
        getorcreate!

    using Distributions

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (nothing,))
    @test xref == xref
    @test_throws(
        "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time.",
        xref != 1
    )
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." 1 !=
        xref
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." xref ==
        1
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." 1 ==
        xref
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." xref >
        0
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." 0 <
        xref
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." "something" ==
        xref
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." 10 >
        xref
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." xref <
        10
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." 0 <=
        xref
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." xref >=
        0
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." xref <=
        0
    @test_throws "Comparing Factor Graph variable `x` with a value. This is not possible as the value of `x` is not known at model construction time." 0 >=
        xref

    xref = VariableRef(model, ctx, NodeCreationOptions(), :x, (1, 2))
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." xref !=
        1
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." 1 !=
        xref
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." xref ==
        1
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." 1 ==
        xref
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." xref >
        0
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." 0 <
        xref
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." "something" ==
        xref
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." 10 >
        xref
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." xref <
        10
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." 0 <=
        xref
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." xref >=
        0
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." xref <=
        0
    @test_throws "Comparing Factor Graph variable `x[1,2]` with a value. This is not possible as the value of `x[1,2]` is not known at model construction time." 0 >=
        xref
end