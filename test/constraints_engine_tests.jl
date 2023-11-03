@testitem "FactorizationConstraintEntry" begin
    import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    # Test 1: Test FactorisationConstraintEntry
    @test FactorizationConstraintEntry((
        IndexedVariable(:x, nothing),
        IndexedVariable(:y, nothing),
    )) isa FactorizationConstraintEntry

    a = FactorizationConstraintEntry((
        IndexedVariable(:x, nothing),
        IndexedVariable(:y, nothing),
    ))
    b = FactorizationConstraintEntry((
        IndexedVariable(:x, nothing),
        IndexedVariable(:y, nothing),
    ))
    @test a == b
    c = FactorizationConstraintEntry((
        IndexedVariable(:x, nothing),
        IndexedVariable(:y, nothing),
        IndexedVariable(:z, nothing),
    ))
    @test a != c
    d = FactorizationConstraintEntry((
        IndexedVariable(:x, nothing),
        IndexedVariable(:p, nothing),
    ))
    @test a != d

    # Test 2: Test FactorisationConstraintEntry with mixed IndexedVariable types
    a = FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, nothing)))
end

@testitem "CombinedRange" begin
    import GraphPPL: CombinedRange, is_splitted, FunctionalIndex
    for left = 1:3, right = 5:8
        cr = CombinedRange(left, right)

        @test firstindex(cr) === left
        @test lastindex(cr) === right
        @test !is_splitted(cr)
        @test length(cr) === lastindex(cr) - firstindex(cr) + 1

        for i = left:right
            @test i ∈ cr
            @test !((i + lastindex(cr) + 1) ∈ cr)
        end
    end
    range =
        CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test firstindex(range).f === firstindex
    @test lastindex(range).f === lastindex
    @test_throws MethodError length(range)
end

@testitem "SplittedRange" begin
    import GraphPPL: SplittedRange, is_splitted, FunctionalIndex
    for left = 1:3, right = 5:8
        cr = SplittedRange(left, right)

        @test firstindex(cr) === left
        @test lastindex(cr) === right
        @test is_splitted(cr)
        @test length(cr) === lastindex(cr) - firstindex(cr) + 1

        for i = left:right
            @test i ∈ cr
            @test !((i + lastindex(cr) + 1) ∈ cr)
        end
    end
    range =
        SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test firstindex(range).f === firstindex
    @test lastindex(range).f === lastindex
    @test_throws MethodError length(range)
end

@testitem "__factorization_specification_resolve_index" begin
    using GraphPPL
    import GraphPPL:
        __factorization_specification_resolve_index,
        FunctionalIndex,
        CombinedRange,
        SplittedRange,
        NodeLabel,
        ResizableArray

    collection = ResizableArray(NodeLabel, Val(1))
    for i = 1:10
        collection[i] = NodeLabel(:x, i)
    end

    # Test 1: Test __factorization_specification_resolve_index with FunctionalIndex
    index = FunctionalIndex{:begin}(firstindex)
    @test __factorization_specification_resolve_index(index, collection) ===
          firstindex(collection)

    @test_throws ErrorException __factorization_specification_resolve_index(
        index,
        collection[1],
    )

    # Test 2: Test __factorization_specification_resolve_index with CombinedRange
    index = CombinedRange(1, 5)
    @test __factorization_specification_resolve_index(index, collection) === index
    index =
        CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) ===
          CombinedRange(1, 10)
    index = CombinedRange(5, FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) ===
          CombinedRange(5, 10)
    index = CombinedRange(1, 20)
    @test_throws ErrorException __factorization_specification_resolve_index(
        index,
        collection,
    )

    @test_throws ErrorException __factorization_specification_resolve_index(
        index,
        collection[1],
    )

    # Test 3: Test __factorization_specification_resolve_index with SplittedRange
    index = SplittedRange(1, 5)
    @test __factorization_specification_resolve_index(index, collection) === index
    index =
        SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) ===
          SplittedRange(1, 10)
    index = SplittedRange(5, FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) ===
          SplittedRange(5, 10)
    index = SplittedRange(1, 20)
    @test_throws ErrorException __factorization_specification_resolve_index(
        index,
        collection,
    )

    @test_throws ErrorException __factorization_specification_resolve_index(
        index,
        collection[1],
    )

    # Test 4: Test __factorization_specification_resolve_index with Array of indices
    index = SplittedRange(
        [FunctionalIndex{:begin}(firstindex), FunctionalIndex{:begin}(firstindex)],
        [FunctionalIndex{:end}(lastindex), FunctionalIndex{:end}(lastindex)],
    )
    collection = GraphPPL.ResizableArray(GraphPPL.NodeLabel, Val(2))
    for i = 1:3
        for j = 1:5
            collection[i, j] = GraphPPL.NodeLabel(:x, i * j)
        end
    end

    #@bvdmitri we should check if we should allow this at all (i.e. x[begin, begin]..x[end, end]), otherwise we can delete these broken tests and just disallow in general. I remember you saying this isn't possible, but I don't remember if it referenced this exact problem.

    @test_broken __factorization_specification_resolve_index(index, collection) ===
                 SplittedRange([1, 1], [3, 5])
end

@testitem "factorization_split" begin
    import GraphPPL:
        factorization_split,
        FactorizationConstraintEntry,
        IndexedVariable,
        FunctionalIndex,
        CombinedRange,
        SplittedRange

    # Test 1: Test factorization_split with single split
    @test factorization_split(
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
            )),
        ),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
            )),
        ),
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(
                :x,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        ),),
    )

    @test factorization_split(
        (
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
            )),
        ),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
            )),
            FactorizationConstraintEntry((IndexedVariable(:z, nothing),)),
        ),
    ) == (
        FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        FactorizationConstraintEntry((
            IndexedVariable(
                :x,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        )),
        FactorizationConstraintEntry((IndexedVariable(:z, nothing),)),
    )

    @test factorization_split(
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
            )),
        ),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
                IndexedVariable(:y, FunctionalIndex{:end}(lastindex)),
            )),
        ),
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(
                :x,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
            IndexedVariable(
                :y,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        )),
    )

    # Test factorization_split with only FactorizationConstraintEntrys
    @test factorization_split(
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
            IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
        )),
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
            IndexedVariable(:y, FunctionalIndex{:end}(lastindex)),
        )),
    ) == FactorizationConstraintEntry((
        IndexedVariable(
            :x,
            SplittedRange(
                FunctionalIndex{:begin}(firstindex),
                FunctionalIndex{:end}(lastindex),
            ),
        ),
        IndexedVariable(
            :y,
            SplittedRange(
                FunctionalIndex{:begin}(firstindex),
                FunctionalIndex{:end}(lastindex),
            ),
        ),
    ))

    # Test mixed behaviour 
    @test factorization_split(
        (
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
            )),
        ),
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
        )),
    ) == (
        FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        FactorizationConstraintEntry((
            IndexedVariable(
                :x,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        )),
    )

    @test factorization_split(
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
        )),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
            )),
            FactorizationConstraintEntry((IndexedVariable(:z, nothing),),),
        ),
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(
                :x,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        )),
        FactorizationConstraintEntry((IndexedVariable(:z, nothing),)),
    )
end

@testitem "FactorizationConstraint" begin
    import GraphPPL:
        FactorizationConstraint,
        FactorizationConstraintEntry,
        IndexedVariable,
        FunctionalIndex,
        CombinedRange,
        SplittedRange

    # Test 1: Test FactorizationConstraint with single variables
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            )),
        ),
    ) isa Any
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        ),
    ) isa Any
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),),
    )
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            )),
        ),
    )

    # Test 2: Test FactorizationConstraint with indexed variables
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, 1))),),
    ) isa Any
    @test FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, 1),)),
            FactorizationConstraintEntry((IndexedVariable(:y, 1),)),
        ),
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1),)),),
    )
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, 1),),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, 1))),),
    )

    # Test 3: Test FactorizationConstraint with SplittedRanges
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            )),
        ),
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
                IndexedVariable(:y, nothing),
            )),
        ),
    )

    # Test 4: Test FactorizationConstraint with CombinedRanges
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(
                    :x,
                    CombinedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            )),
        ),
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(
                    :x,
                    CombinedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
                IndexedVariable(:y, nothing),
            )),
        ),
    )

    # Test 5: Test FactorizationConstraint  with duplicate entries
    @test_throws ErrorException constraint = FactorizationConstraint(
        (
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
            IndexedVariable(:out, nothing),
        ),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:out, nothing),)),
        ),
    )
end

@testitem "multiply(::FactorizationConstraintEntry, ::FactorizationConstraintEntry)" begin
    import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    entry = FactorizationConstraintEntry((
        IndexedVariable(:x, nothing),
        IndexedVariable(:y, nothing),
    ))
    global x = entry
    for i = 1:3
        global x = x * x
        @test x == Tuple([entry for _ = 1:(2^i)])
    end
end

@testitem "push!(::Constraints, ::Constraint)" begin
    using Distributions
    import GraphPPL:
        Constraints,
        Constraint,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        FunctionalFormConstraint,
        MessageConstraint,
        SpecificSubModelConstraints,
        GeneralSubModelConstraints,
        IndexedVariable,
        FactorID

    # Test 1: Test push! with FactorizationConstraint
    constraints = Constraints()
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            ),),
        ),
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            )),
        ),
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FactorizationConstraint(
        (IndexedVariable(:y, nothing), IndexedVariable(:x, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            )),
        ),
    )
    @test_throws ErrorException push!(constraints, constraint)

    # Test 2: Test push! with FunctionalFormConstraint
    constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FunctionalFormConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        Normal,
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FunctionalFormConstraint(IndexedVariable(:x, 1), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint =
        FunctionalFormConstraint([IndexedVariable(:x, 1), IndexedVariable(:y, 1)], Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 3: Test push! with MessageConstraint
    constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = MessageConstraint(IndexedVariable(:x, 2), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 4: Test push! with SpecificSubModelConstraints
    constraint = SpecificSubModelConstraints(FactorID(sum, 3), Constraints())
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 5: Test push! with GeneralSubModelConstraints
    constraint = GeneralSubModelConstraints(sum, Constraints())
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
end

@testitem "push!(::SubModelConstraints, c::Constraint)" begin
    include("model_zoo.jl")
    using GraphPPL
    import GraphPPL:
        Constraint,
        GeneralSubModelConstraints,
        SpecificSubModelConstraints,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        FunctionalFormConstraint,
        MessageConstraint,
        getconstraint,
        Constraints,
        IndexedVariable

    # Test 1: Test push! with FactorizationConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            )),
        ),
    )
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([
        FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (
                FactorizationConstraintEntry((
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ),),
            ),
        ),
    ],)
    @test_throws MethodError push!(constraints, "string")

    # Test 2: Test push! with FunctionalFormConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) ==
          Constraints([FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 3: Test push! with MessageConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) ==
          Constraints([MessageConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 4: Test push! with SpecificSubModelConstraints
    constraints = SpecificSubModelConstraints(GraphPPL.FactorID(gcv, 3))
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
            )),
        ),
    )
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([
        FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (
                FactorizationConstraintEntry((
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ),),
            ),
        ),
    ],)
    @test_throws MethodError push!(constraints, "string")

    # Test 5: Test push! with FunctionalFormConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) ==
          Constraints([FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 6: Test push! with MessageConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) ==
          Constraints([MessageConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

end


@testitem "is_valid_partition(::Set)" begin
    using GraphPPL
    import GraphPPL: is_valid_partition

    # Test 1: Test that is_valid_partition returns true for a valid partition
    @test is_valid_partition(Set([BitSet([1, 2]), BitSet([3, 4])])) == true

    # Test 2: Test that is_valid_partition returns false for an invalid partition
    @test is_valid_partition(Set([BitSet([1, 2]), BitSet([2, 3])])) == false

    # Test 3: Test that is_valid_partition returns false for an invalid partition
    @test is_valid_partition(Set([BitSet([1, 2]), BitSet([2, 3]), BitSet([3, 4])])) == false

    # Test 4: Test that is_valid_partition returns false for an invalid partition
    @test is_valid_partition(Set([BitSet([1, 2]), BitSet([4, 5])])) == false
end

@testitem "constant_constraint" begin
    using BitSetTuples
    import GraphPPL: constant_constraint

    @test constant_constraint(1, 1) == BitSetTuple(1)
    @test constant_constraint(5, 3) ==
          BitSetTuple([[1, 2, 4, 5], [1, 2, 4, 5], [3], [1, 2, 4, 5], [1, 2, 4, 5]])
end

@testitem "save constraints with constants" begin
    include("model_zoo.jl")
    using BitSetTuples
    using GraphPPL
    import GraphPPL: save_constraint!, constant_constraint, factorization_constraint

    model = create_terminated_model(simple_model)
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]
    save_constraint!(model, node, constant_constraint(3, 1), :q)
    @test factorization_constraint(model[node]) == BitSetTuple([[1], [2, 3], [2, 3]])
    save_constraint!(model, node, constant_constraint(3, 2), :q)
    @test factorization_constraint(model[node]) == BitSetTuple([[1], [2], [3]])

    node = ctx[NormalMeanVariance, 1]
    save_constraint!(model, node, constant_constraint(3, 1), :q)
    @test factorization_constraint(model[node]) == BitSetTuple([[1], [2, 3], [2, 3]])
end


@testitem "materialize_constraints!(:Model, ::NodeLabel, ::FactorNodeData)" begin
    include("model_zoo.jl")
    using BitSetTuples
    using GraphPPL
    import GraphPPL:
        materialize_constraints!,
        EdgeLabel,
        node_options,
        apply!,
        get_constraint_names,
        factorization_constraint

    # Test 1: Test materialize with a Full Factorization constraint
    model = create_terminated_model(simple_model)
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]
    materialize_constraints!(model, node)
    @test get_constraint_names(factorization_constraint(model[node])) == ((:μ, :σ, :out),)
    materialize_constraints!(model, ctx[NormalMeanVariance, 1])
    @test get_constraint_names(
        factorization_constraint(model[ctx[NormalMeanVariance, 1]]),
    ) == ((:out,), (:μ,), (:σ,))

    # Test 2: Test materialize with an applied constraint
    model = create_terminated_model(simple_model)
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]
    GraphPPL.save_constraint!(
        model,
        node,
        model[node],
        BitSetTuple([[1], [2, 3], [2, 3]]),
        :q,
    )
    materialize_constraints!(model, node)
    @test get_constraint_names(factorization_constraint(model[node])) == ((:μ,), (:σ, :out))

    # Test 3: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_terminated_model(simple_model)
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]
    GraphPPL.save_constraint!(model, node, model[node], BitSetTuple([[1], [3], [2, 3]]), :q)
    @test_throws ErrorException materialize_constraints!(model, node)

    # Test 4: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_terminated_model(simple_model)
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]
    GraphPPL.save_constraint!(model, node, model[node], BitSetTuple([[1], [1], [3]]), :q)
    @test_throws ErrorException materialize_constraints!(model, node)
end

@testitem "Resolve Factorization Constraints" begin
    include("model_zoo.jl")
    using GraphPPL
    import GraphPPL:
        FactorizationConstraint,
        FactorizationConstraintEntry,
        IndexedVariable,
        resolve,
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        CombinedRange,
        SplittedRange

    model = create_terminated_model(outer)
    ctx = GraphPPL.getcontext(model)
    inner_context = ctx[inner, 1]

    # Test resolve constraint in child model

    let constraint = FactorizationConstraint(
            (IndexedVariable(:α, nothing), IndexedVariable(:θ, nothing)),
            (
                FactorizationConstraintEntry((IndexedVariable(:α, nothing),)),
                FactorizationConstraintEntry((IndexedVariable(:θ, nothing),)),
            ),
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:y, nothing, ctx),
                ResolvedIndexedVariable(:w, CombinedRange(2, 3), ctx),
            ),),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:y, nothing, ctx),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, CombinedRange(2, 3), ctx),
                )),
            ),
        )
        @test resolve(model, inner_context, constraint) == result
    end

    # Test constraint in top level model

    let constraint = FactorizationConstraint(
            (IndexedVariable(:y, nothing), IndexedVariable(:w, nothing)),
            (
                FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
                FactorizationConstraintEntry((IndexedVariable(:w, nothing),)),
            ),
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:y, nothing, ctx),
                ResolvedIndexedVariable(:w, CombinedRange(1, 5), ctx),
            ),),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:y, nothing, ctx),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, CombinedRange(1, 5), ctx),
                )),
            ),
        )
        @test resolve(model, ctx, constraint) == result
    end

    # Test a constraint that is not applicable at all

    let constraint = FactorizationConstraint(
            (
                IndexedVariable(:i, nothing),
                IndexedVariable(:dont, nothing),
                IndexedVariable(:apply, nothing),
            ),
            (
                FactorizationConstraintEntry((IndexedVariable(:i, nothing),)),
                FactorizationConstraintEntry((IndexedVariable(:dont, nothing),)),
                FactorizationConstraintEntry((IndexedVariable(:apply, nothing),)),
            ),
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
            ),),
            (
                ResolvedFactorizationConstraintEntry((
                )),
                ResolvedFactorizationConstraintEntry((
                )),
                ResolvedFactorizationConstraintEntry((
                )),
            ),
        )
        @test resolve(model, ctx, constraint) == result
    end

end

@testitem "Resolved Constraints in" begin
    using GraphPPL
    import GraphPPL:
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        SplittedRange,
        getname,
        index

    context = GraphPPL.Context()
    variable = ResolvedIndexedVariable(:w, 2:3, context)
    node_data = GraphPPL.VariableNodeData(:w, NamedTuple{}(), 2, context)
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:w, 2:3, context)
    node_data = GraphPPL.VariableNodeData(:w, NamedTuple{}(), 2, GraphPPL.Context())
    @test !(node_data ∈ variable)

    variable = ResolvedIndexedVariable(:w, 2, context)
    node_data = GraphPPL.VariableNodeData(:w, NamedTuple{}(), 2, context)
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:w, SplittedRange(2, 3), context)
    node_data = GraphPPL.VariableNodeData(:w, NamedTuple{}(), 2, context)
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:w, SplittedRange(10, 15), context)
    node_data = GraphPPL.VariableNodeData(:w, NamedTuple{}(), 2, context)
    @test !(node_data ∈ variable)

    variable = ResolvedIndexedVariable(:x, nothing, context)
    node_data = GraphPPL.VariableNodeData(:x, NamedTuple{}(), 2, context)
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:x, nothing, context)
    node_data = GraphPPL.VariableNodeData(:x, NamedTuple{}(), nothing, context)
    @test node_data ∈ variable
end

@testitem "ResolvedFactorizationConstraint" begin
    import GraphPPL:
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        SplittedRange,
        CombinedRange,
        apply!

    using BitSetTuples

    include("model_zoo.jl")

    __model__ = create_terminated_model(outer)
    __context__ = GraphPPL.getcontext(__model__)
    __inner_context__ = __context__[inner, 1]
    __inner_inner_context__ = __inner_context__[inner_inner, 1]

    __normal_node__ = __inner_inner_context__[NormalMeanVariance, 1]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, __context__),)),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 2, __context__),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 3, __context__),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1, 3], [2, 3], [1, 2, 3]])
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 4:5, __context__),)),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 4, __context__),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 5, __context__),
                )),
            ),
        )
        @test !GraphPPL.is_applicable(__model__, __normal_node__, constraint)
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, __context__),)),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, SplittedRange(2, 3), __context__),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1, 3], [2, 3], [1, 2, 3]])
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:w, 2:3, __context__),
                ResolvedIndexedVariable(:y, nothing, __context__),
            )),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, SplittedRange(2, 3), __context__),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:y, nothing, __context__),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1], [2], [3]])
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:w, 2:3, __context__),
                ResolvedIndexedVariable(:y, nothing, __context__),
            )),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 2, __context__),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 3, __context__),
                    ResolvedIndexedVariable(:y, nothing, __context__),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1], [2, 3], [2, 3]])
        apply!(__model__, __normal_node__, constraint)
        @test GraphPPL.factorization_constraint(__model__[__normal_node__]) ==
              BitSetTuple([[1], [2, 3], [2, 3]])
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:w, 2:3, __context__),
                ResolvedIndexedVariable(:y, nothing, __context__),
            )),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, CombinedRange(2, 3), __context__),
                )),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:y, nothing, __context__),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1, 2], [1, 2], [3]])
    end

    __model__ = create_terminated_model(multidim_array)
    __context__ = GraphPPL.getcontext(__model__)
    __normal_node__ = __context__[NormalMeanVariance, 5]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:x, nothing, __context__),),),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(
                        :x,
                        SplittedRange(CartesianIndex(1, 1), CartesianIndex(3, 3)),
                        __context__,
                    ),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1, 3], [2, 3], [1, 2, 3]])
        apply!(__model__, __normal_node__, constraint)
        @test GraphPPL.factorization_constraint(__model__[__normal_node__]) ==
              BitSetTuple([[1, 3], [2, 3], [1, 2, 3]])

    end

    __model__ = create_terminated_model(multidim_array)
    __context__ = GraphPPL.getcontext(__model__)
    __normal_node__ = __context__[NormalMeanVariance, 5]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:x, nothing, __context__),),),
            (
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(
                        :x,
                        CombinedRange(CartesianIndex(1, 1), CartesianIndex(3, 3)),
                        __context__,
                    ),
                )),
            ),
        )
        @test GraphPPL.is_applicable(__model__, __normal_node__, constraint)
        @test GraphPPL.convert_to_bitsets(__model__, __normal_node__, constraint) ==
              BitSetTuple([[1, 2, 3], [1, 2, 3], [1, 2, 3]])
        apply!(__model__, __normal_node__, constraint)
        @test GraphPPL.factorization_constraint(__model__[__normal_node__]) ==
              BitSetTuple([[1, 2, 3], [1, 2, 3], [1, 2, 3]])

    end
end
