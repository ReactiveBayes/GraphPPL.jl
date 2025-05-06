@testitem "NodeLabel properties" begin
    import GraphPPL: NodeLabel

    xref = NodeLabel(:x, 1)
    @test xref[1] == xref
    @test length(xref) === 1
    @test GraphPPL.to_symbol(xref) === :x_1

    y = NodeLabel(:y, 2)
    @test xref < y
end

@testitem "getname(::NodeLabel)" begin
    import GraphPPL: ResizableArray, NodeLabel, getname

    xref = NodeLabel(:x, 1)
    @test getname(xref) == :x

    xref = ResizableArray(NodeLabel, Val(1))
    xref[1] = NodeLabel(:x, 1)
    @test getname(xref) == :x

    xref = ResizableArray(NodeLabel, Val(1))
    xref[2] = NodeLabel(:x, 1)
    @test getname(xref) == :x
end

@testitem "generate_nodelabel(::Model, ::Symbol)" begin
    import GraphPPL: create_model, gensym, NodeLabel, generate_nodelabel

    include("testutils.jl")

    model = create_test_model()
    first_sym = generate_nodelabel(model, :x)
    @test typeof(first_sym) == NodeLabel

    second_sym = generate_nodelabel(model, :x)
    @test first_sym != second_sym && first_sym.name == second_sym.name

    id = generate_nodelabel(model, :c)
    @test id.name == :c && id.global_counter == 3
end

@testitem "proxy labels" begin
    import GraphPPL: NodeLabel, ProxyLabel, proxylabel, getname, unroll, ResizableArray, FunctionalIndex

    y = NodeLabel(:y, 1)

    let p = proxylabel(:x, y, nothing)
        @test last(p) === y
        @test getname(p) === :x
        @test getname(last(p)) === :y
    end

    let p = proxylabel(:x, y, (1,))
        @test_throws "Indexing a single node label `y` with an index `[1]` is not allowed" unroll(p)
    end

    let p = proxylabel(:x, y, (1, 2))
        @test_throws "Indexing a single node label `y` with an index `[1, 2]` is not allowed" unroll(p)
    end

    let p = proxylabel(:r, proxylabel(:x, y, nothing), nothing)
        @test last(p) === y
        @test getname(p) === :r
        @test getname(last(p)) === :y
    end

    for n in (5, 10)
        s = ResizableArray(NodeLabel, Val(1))

        for i in 1:n
            s[i] = NodeLabel(:s, i)
        end

        let p = proxylabel(:x, s, nothing)
            @test last(p) === s
            @test all(i -> p[i] === s[i], 1:length(s))
            @test unroll(p) === s
        end

        for i in 1:5
            let p = proxylabel(:r, proxylabel(:x, s, (i,)), nothing)
                @test unroll(p) === s[i]
            end
        end

        let p = proxylabel(:r, proxylabel(:x, s, (2:4,)), (2,))
            @test unroll(p) === s[3]
        end
        let p = proxylabel(:x, s, (2:4,))
            @test p[1] === s[2]
        end
    end

    for n in (5, 10)
        s = ResizableArray(NodeLabel, Val(1))

        for i in 1:n
            s[i] = NodeLabel(:s, i)
        end

        let p = proxylabel(:x, s, FunctionalIndex{:begin}(firstindex))
            @test unroll(p) === s[begin]
        end
    end
end

@testitem "datalabel" begin
    import GraphPPL: getcontext, datalabel, NodeCreationOptions, VariableKindData, VariableKindRandom, unroll, proxylabel

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    ylabel = datalabel(model, ctx, NodeCreationOptions(kind = VariableKindData), :y)
    yvar = unroll(ylabel)
    @test haskey(ctx, :y) && ctx[:y] === yvar
    @test GraphPPL.nv(model) === 1
    # subsequent unroll should return the same variable
    unroll(ylabel)
    @test haskey(ctx, :y) && ctx[:y] === yvar
    @test GraphPPL.nv(model) === 1

    yvlabel = datalabel(model, ctx, NodeCreationOptions(kind = VariableKindData), :yv, [1, 2, 3])
    for i in 1:3
        yvvar = unroll(proxylabel(:yv, yvlabel, (i,)))
        @test haskey(ctx, :yv) && ctx[:yv][i] === yvvar
        @test GraphPPL.nv(model) === 1 + i
    end
    # Incompatible data indices
    @test_throws "The index `[4]` is not compatible with the underlying collection provided for the label `yv`" unroll(
        proxylabel(:yv, yvlabel, (4,))
    )
    @test_throws "The underlying data provided for `yv` is `[1, 2, 3]`" unroll(proxylabel(:yv, yvlabel, (4,)))

    @test_throws "`datalabel` only supports `VariableKindData` in `NodeCreationOptions`" datalabel(model, ctx, NodeCreationOptions(), :z)
    @test_throws "`datalabel` only supports `VariableKindData` in `NodeCreationOptions`" datalabel(
        model, ctx, NodeCreationOptions(kind = VariableKindRandom), :z
    )
end

@testitem "contains_nodelabel" begin
    import GraphPPL: create_model, getcontext, getorcreate!, contains_nodelabel, NodeCreationOptions, True, False, MixedArguments

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    a = getorcreate!(model, ctx, :x, nothing)
    b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :x, nothing)
    c = 1.0

    # Test 1. Tuple based input
    @test contains_nodelabel((a, b, c)) === True()
    @test contains_nodelabel((a, b)) === True()
    @test contains_nodelabel((a,)) === True()
    @test contains_nodelabel((b,)) === True()
    @test contains_nodelabel((c,)) === False()

    # Test 2. Named tuple based input
    @test @inferred(contains_nodelabel((; a = a, b = b, c = c))) === True()
    @test @inferred(contains_nodelabel((; a = a, b = b))) === True()
    @test @inferred(contains_nodelabel((; a = a))) === True()
    @test @inferred(contains_nodelabel((; b = b))) === True()
    @test @inferred(contains_nodelabel((; c = c))) === False()

    # Test 3. MixedArguments based input
    @test @inferred(contains_nodelabel(MixedArguments((), (; a = a, b = b, c = c)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; a = a, b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; a = a)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; c = c)))) === False()

    @test @inferred(contains_nodelabel(MixedArguments((a,), (; b = b, c = c)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((c,), (; a = a, b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((b,), (; a = a)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((c,), (; b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((c,), (;)))) === False()
    @test @inferred(contains_nodelabel(MixedArguments((), (; c = c)))) === False()
end