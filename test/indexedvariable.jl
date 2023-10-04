module test_indexed_variable

using ReTestItems



@testitem "IndexedVariable" begin
    import GraphPPL: IndexedVariable, CombinedRange, SplittedRange

    # Test 1: Test IndexedVariable
    @test IndexedVariable(:x, nothing) isa IndexedVariable

    # Test 2: Test IndexedVariable equality
    lhs = IndexedVariable(:x, nothing)
    rhs = IndexedVariable(:x, nothing)
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:y, nothing)
    @test lhs !== IndexedVariable(:y, nothing)

    # Test 3: Test IndexedVariable with CombinedRange equality
    lhs = IndexedVariable(:x, CombinedRange(1, 2))
    rhs = IndexedVariable(:x, CombinedRange(1, 2))
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:x, CombinedRange(1, 3))
    @test lhs !== IndexedVariable(:x, CombinedRange(1, 3))
    @test lhs != IndexedVariable(:y, CombinedRange(1, 2))
    @test lhs !== IndexedVariable(:y, CombinedRange(1, 2))

    # Test 4: Test IndexedVariable with SplittedRange equality
    lhs = IndexedVariable(:x, SplittedRange(1, 2))
    rhs = IndexedVariable(:x, SplittedRange(1, 2))
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:x, SplittedRange(1, 3))
    @test lhs !== IndexedVariable(:x, SplittedRange(1, 3))
    @test lhs != IndexedVariable(:y, SplittedRange(1, 2))
    @test lhs !== IndexedVariable(:y, SplittedRange(1, 2))
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
end
end
