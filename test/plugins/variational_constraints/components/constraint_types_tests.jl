@testitem "FactorizationConstraintEntry" setup = [TestUtils] begin
    import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    # Test 1: Test FactorisationConstraintEntry
    @test FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))) isa FactorizationConstraintEntry

    a = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)))
    b = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)))
    @test a == b
    c = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing), IndexedVariable(:z, nothing)))
    @test a != c
    d = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:p, nothing)))
    @test a != d

    # Test 2: Test FactorisationConstraintEntry with mixed IndexedVariable types
    a = FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, nothing)))
end

@testitem "multiply(::FactorizationConstraintEntry, ::FactorizationConstraintEntry)" begin
    import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    entry = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)))
    global x = entry
    for i in 1:3
        global x = x * x
        @test x == Tuple([entry for _ in 1:(2^i)])
    end
end

@testitem "FactorizationConstraint" setup = [TestUtils] begin
    import GraphPPL: FactorizationConstraint, FactorizationConstraintEntry, IndexedVariable, FunctionalIndex, CombinedRange, SplittedRange

    # Test 1: Test FactorizationConstraint with single variables
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    ) isa Any
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)), FactorizationConstraintEntry((IndexedVariable(:y, nothing),)))
    ) isa Any
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)), (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),)
    )
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing),), (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )

    # Test 2: Test FactorizationConstraint with indexed variables
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, 1))),)
    ) isa Any
    @test FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1),)), FactorizationConstraintEntry((IndexedVariable(:y, 1),)))
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)), (FactorizationConstraintEntry((IndexedVariable(:x, 1),)),)
    )
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, 1),), (FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, 1))),)
    )

    # Test 3: Test FactorizationConstraint with SplittedRanges
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
            )),
        )
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
                IndexedVariable(:y, nothing)
            )),
        )
    )

    # Test 4: Test FactorizationConstraint with CombinedRanges
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
            )),
        )
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
                IndexedVariable(:y, nothing)
            )),
        )
    )

    # Test 5: Test FactorizationConstraint  with duplicate entries
    @test_throws ErrorException constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing), IndexedVariable(:out, nothing)),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:out, nothing),))
        )
    )
end