@testitem "CombinedRange" setup = [TestUtils] begin
    import GraphPPL: CombinedRange, is_splitted, FunctionalIndex, IndexedVariable
    for left in 1:3, right in 5:8
        cr = CombinedRange(left, right)

        @test firstindex(cr) === left
        @test lastindex(cr) === right
        @test !is_splitted(cr)
        @test length(cr) === lastindex(cr) - firstindex(cr) + 1

        for i in left:right
            @test i ∈ cr
            @test !((i + lastindex(cr) + 1) ∈ cr)
        end
    end
    range = CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test firstindex(range).f === firstindex
    @test lastindex(range).f === lastindex
    @test_throws MethodError length(range)

    # Test IndexedVariable with CombinedRange equality
    lhs = IndexedVariable(:x, CombinedRange(1, 2))
    rhs = IndexedVariable(:x, CombinedRange(1, 2))
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:x, CombinedRange(1, 3))
    @test lhs !== IndexedVariable(:x, CombinedRange(1, 3))
    @test lhs != IndexedVariable(:y, CombinedRange(1, 2))
    @test lhs !== IndexedVariable(:y, CombinedRange(1, 2))
end

@testitem "SplittedRange" setup = [TestUtils] begin
    import GraphPPL: SplittedRange, is_splitted, FunctionalIndex, IndexedVariable
    for left in 1:3, right in 5:8
        cr = SplittedRange(left, right)

        @test firstindex(cr) === left
        @test lastindex(cr) === right
        @test is_splitted(cr)
        @test length(cr) === lastindex(cr) - firstindex(cr) + 1

        for i in left:right
            @test i ∈ cr
            @test !((i + lastindex(cr) + 1) ∈ cr)
        end
    end
    range = SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test firstindex(range).f === firstindex
    @test lastindex(range).f === lastindex
    @test_throws MethodError length(range)

    # Test IndexedVariable with SplittedRange equality
    lhs = IndexedVariable(:x, SplittedRange(1, 2))
    rhs = IndexedVariable(:x, SplittedRange(1, 2))
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:x, SplittedRange(1, 3))
    @test lhs !== IndexedVariable(:x, SplittedRange(1, 3))
    @test lhs != IndexedVariable(:y, SplittedRange(1, 2))
    @test lhs !== IndexedVariable(:y, SplittedRange(1, 2))
end

@testitem "__factorization_specification_resolve_index" setup = [TestUtils] begin
    using GraphPPL
    import GraphPPL: __factorization_specification_resolve_index, FunctionalIndex, CombinedRange, SplittedRange, NodeLabel, ResizableArray

    collection = ResizableArray(NodeLabel, Val(1))
    for i in 1:10
        collection[i] = NodeLabel(:x, i)
    end

    # Test 1: Test __factorization_specification_resolve_index with FunctionalIndex
    index = FunctionalIndex{:begin}(firstindex)
    @test __factorization_specification_resolve_index(index, collection) === firstindex(collection)

    @test_throws ErrorException __factorization_specification_resolve_index(index, collection[1])

    # Test 2: Test __factorization_specification_resolve_index with CombinedRange
    index = CombinedRange(1, 5)
    @test __factorization_specification_resolve_index(index, collection) === index
    index = CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === CombinedRange(1, 10)
    index = CombinedRange(5, FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === CombinedRange(5, 10)
    index = CombinedRange(1, 20)
    @test_throws ErrorException __factorization_specification_resolve_index(index, collection)

    @test_throws ErrorException __factorization_specification_resolve_index(index, collection[1])

    # Test 3: Test __factorization_specification_resolve_index with SplittedRange
    index = SplittedRange(1, 5)
    @test __factorization_specification_resolve_index(index, collection) === index
    index = SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === SplittedRange(1, 10)
    index = SplittedRange(5, FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === SplittedRange(5, 10)
    index = SplittedRange(1, 20)
    @test_throws ErrorException __factorization_specification_resolve_index(index, collection)

    @test_throws ErrorException __factorization_specification_resolve_index(index, collection[1])

    # Test 4: Test __factorization_specification_resolve_index with Array of indices
    index = SplittedRange(
        [FunctionalIndex{:begin}(firstindex), FunctionalIndex{:begin}(firstindex)],
        [FunctionalIndex{:end}(lastindex), FunctionalIndex{:end}(lastindex)]
    )
    collection = GraphPPL.ResizableArray(GraphPPL.NodeLabel, Val(2))
    for i in 1:3
        for j in 1:5
            collection[i, j] = GraphPPL.NodeLabel(:x, i * j)
        end
    end
end

@testitem "factorization_split" setup = [TestUtils] begin
    import GraphPPL: factorization_split, FactorizationConstraintEntry, IndexedVariable, FunctionalIndex, CombinedRange, SplittedRange

    # Test 1: Test factorization_split with single split
    @test factorization_split(
        (FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),)),),
        (FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),)),)
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        ),),
    )

    @test factorization_split(
        (
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),))
        ),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),)),
            FactorizationConstraintEntry((IndexedVariable(:z, nothing),))
        )
    ) == (
        FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        )),
        FactorizationConstraintEntry((IndexedVariable(:z, nothing),))
    )

    @test factorization_split(
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)), IndexedVariable(:y, FunctionalIndex{:begin}(firstindex))
            )),
        ),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)), IndexedVariable(:y, FunctionalIndex{:end}(lastindex))
            )),
        )
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
            IndexedVariable(:y, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex)))
        )),
    )

    # Test factorization_split with only FactorizationConstraintEntrys
    @test factorization_split(
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)), IndexedVariable(:y, FunctionalIndex{:begin}(firstindex))
        )),
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:end}(lastindex)), IndexedVariable(:y, FunctionalIndex{:end}(lastindex))
        ))
    ) == FactorizationConstraintEntry((
        IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        IndexedVariable(:y, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex)))
    ))

    # Test mixed behaviour 
    @test factorization_split(
        (
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),))
        ),
        FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),))
    ) == (
        FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        ))
    )

    @test factorization_split(
        FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),)),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),)),
            FactorizationConstraintEntry((IndexedVariable(:z, nothing),),)
        )
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        )),
        FactorizationConstraintEntry((IndexedVariable(:z, nothing),))
    )
end