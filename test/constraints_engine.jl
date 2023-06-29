module test_constraints_engine

using Test
using TestSetExtensions
using GraphPPL
using MacroTools
using StaticArrays
using MetaGraphsNext

include("model_zoo.jl")

@testset ExtendedTestSet "constraints_engine" begin

    @testset "IndexedVariable" begin
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

    @testset "FactorizationConstraintEntry" begin
        import GraphPPL: FactorizationConstraintEntry, IndexedVariable

        # Test 1: Test FactorisationConstraintEntry
        @test FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
        ]) isa FactorizationConstraintEntry

        a = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
        ])
        b = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
        ])
        @test a == b
        c = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
            IndexedVariable(:z, nothing),
        ])
        @test a != c
        d = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:p, nothing),
        ])
        @test a != d

        # Test 2: Test FactorisationConstraintEntry with mixed IndexedVariable types
        a = FactorizationConstraintEntry([
            IndexedVariable(:x, 1),
            IndexedVariable(:y, nothing),
        ])
    end

    @testset "FunctionalIndex" begin
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

    @testset "CombinedRange" begin
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
        range = CombinedRange(
            FunctionalIndex{:begin}(firstindex),
            FunctionalIndex{:end}(lastindex),
        )
        @test firstindex(range).f === firstindex
        @test lastindex(range).f === lastindex
        @test_throws MethodError length(range)
    end

    @testset "SplittedRange" begin
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
        range = SplittedRange(
            FunctionalIndex{:begin}(firstindex),
            FunctionalIndex{:end}(lastindex),
        )
        @test firstindex(range).f === firstindex
        @test lastindex(range).f === lastindex
        @test_throws MethodError length(range)
    end

    @testset "__factorization_specification_resolve_index" begin
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
        index = CombinedRange(
            FunctionalIndex{:begin}(firstindex),
            FunctionalIndex{:end}(lastindex),
        )
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
        index = SplittedRange(
            FunctionalIndex{:begin}(firstindex),
            FunctionalIndex{:end}(lastindex),
        )
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
        @test_broken __factorization_specification_resolve_index(index, collection) ===
                     SplittedRange([1, 1], [3, 5])
    end

    @testset "factorization_split" begin
        import GraphPPL:
            factorization_split,
            FactorizationConstraintEntry,
            IndexedVariable,
            FunctionalIndex,
            CombinedRange,
            SplittedRange

        # Test 1: Test factorization_split with single split
        @test factorization_split(
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                ]),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
                ]),
            ],
        ) == [
            FactorizationConstraintEntry([
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            ]),
        ]
        @test factorization_split(
            [
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                ]),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
            ],
        ) == [
            FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            FactorizationConstraintEntry([
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            ]),
            FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
        ]
        @test factorization_split(
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                    IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
                ]),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
                    IndexedVariable(:y, FunctionalIndex{:end}(lastindex)),
                ]),
            ],
        ) == [
            FactorizationConstraintEntry([
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
            ]),
        ]

        # Test factorization_split with only FactorizationConstraintEntrys
        @test factorization_split(
            FactorizationConstraintEntry([
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
            ]),
            FactorizationConstraintEntry([
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
                IndexedVariable(:y, FunctionalIndex{:end}(lastindex)),
            ]),
        ) == FactorizationConstraintEntry([
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
        ])

        # Test mixed behaviour 
        @test factorization_split(
            [
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                ]),
            ],
            FactorizationConstraintEntry([
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
            ]),
        ) == [
            FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            FactorizationConstraintEntry([
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            ]),
        ]

        @test factorization_split(
            FactorizationConstraintEntry([
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
            ]),
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
            ],
        ) == [
            FactorizationConstraintEntry([
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            ]),
            FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
        ]
    end

    @testset "FactorizationConstraint" begin
        import GraphPPL:
            FactorizationConstraint,
            FactorizationConstraintEntry,
            IndexedVariable,
            FunctionalIndex,
            CombinedRange,
            SplittedRange

        # Test 1: Test FactorizationConstraint with single variables
        @test FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        ) isa Any
        @test FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        ) isa Any
        @test_throws ErrorException FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [FactorizationConstraintEntry([IndexedVariable(:x, nothing)])],
        )
        @test_throws ErrorException FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )

        # Test 2: Test FactorizationConstraint with indexed variables
        @test FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, 1),
                ]),
            ],
        ) isa Any
        @test FactorizationConstraint(
            [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, 1)]),
                FactorizationConstraintEntry([IndexedVariable(:y, 1)]),
            ],
        ) isa Any
        @test_throws ErrorException FactorizationConstraint(
            [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
            [FactorizationConstraintEntry([IndexedVariable(:x, 1)])],
        )
        @test_throws ErrorException FactorizationConstraint(
            [IndexedVariable(:x, 1)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, 1),
                ]),
            ],
        )

        # Test 3: Test FactorizationConstraint with SplittedRanges
        @test FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
            ],
        ) isa Any
        @test_throws ErrorException FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )

        # Test 4: Test FactorizationConstraint with CombinedRanges
        @test FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        CombinedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
            ],
        ) isa Any
        @test_throws ErrorException FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        CombinedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )

        # Test 5: Test FactorizationConstraint  with duplicate entries
        @test_throws ErrorException constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
    end

    @testset "multiply(::FactorisationConstraintEntry, ::FactorisationConstraintEntry)" begin
        import GraphPPL: FactorizationConstraintEntry, IndexedVariable

        entry = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
        ])
        x = entry
        for i = 1:3
            x = x * x
            @test x == [entry for _ = 1:(2^i)]
        end
    end

    @testset "push!(::Constraints, ::Constraint)" begin
        import GraphPPL:
            Constraints,
            Constraint,
            FactorizationConstraint,
            FunctionalFormConstraint,
            MessageConstraint,
            SpecificSubModelConstraints,
            GeneralSubModelConstraints,
            IndexedVariable

        # Test 1: Test push! with FactorizationConstraint
        constraints = Constraints()
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ],),
            ],
        )
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
        constraint = FactorizationConstraint(
            [IndexedVariable(:y, nothing), IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test_throws ErrorException push!(constraints, constraint)

        # Test 2: Test push! with FunctionalFormConstraint
        constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
        constraint = FunctionalFormConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            Normal,
        )
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
        constraint = FunctionalFormConstraint(IndexedVariable(:x, 1), Normal)
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
        constraint = FunctionalFormConstraint(
            [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
            Normal,
        )
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)

        constraint = FunctionalFormConstraint(
            [IndexedVariable(:y, 1), IndexedVariable(:x, 1)],
            Normal,
        )
        @test_broken @test_throws ErrorException push!(constraints, constraint)

        # Test 3: Test push! with MessageConstraint
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
        constraint = MessageConstraint(IndexedVariable(:x, 2), Normal)
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)

        # Test 4: Test push! with SpecificSubModelConstraints
        constraint = SpecificSubModelConstraints(:first_submodel_3, Constraints())
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)

        # Test 5: Test push! with GeneralSubModelConstraints
        constraint = GeneralSubModelConstraints(second_submodel, Constraints())
        push!(constraints, constraint)
        @test_throws ErrorException push!(constraints, constraint)
    end

    @testset "push!(::SubModelConstraints, c::Constraint)" begin
        import GraphPPL:
            SubModelConstraints,
            Constraint,
            FactorizationConstraint,
            FunctionalFormConstraint,
            MessageConstraint,
            getconstraint,
            Constraints

        # Test 1: Test push! with FactorizationConstraint
        constraints = SubModelConstraints(second_submodel)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        push!(constraints, constraint)
        @test getconstraint(constraints) == Constraints(
            GraphPPL.Constraint[FactorizationConstraint(
                [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
                [
                    FactorizationConstraintEntry([
                        IndexedVariable(:x, nothing),
                        IndexedVariable(:y, nothing),
                    ]),
                ],
            ),],
        )
        @test_throws MethodError push!(constraints, "string")

        # Test 2: Test push! with FunctionalFormConstraint
        constraints = SubModelConstraints(second_submodel)
        constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
        push!(constraints, constraint)
        @test getconstraint(constraints) == Constraints(
            GraphPPL.Constraint[FunctionalFormConstraint(
                IndexedVariable(:x, nothing),
                Normal,
            )],
        )
        @test_throws MethodError push!(constraints, "string")

        # Test 3: Test push! with MessageConstraint
        constraints = SubModelConstraints(second_submodel)
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        push!(constraints, constraint)
        @test getconstraint(constraints) == Constraints(
            GraphPPL.Constraint[MessageConstraint(IndexedVariable(:x, nothing), Normal)],
        )
        @test_throws MethodError push!(constraints, "string")

        # Test 4: Test push! with SpecificSubModelConstraints
        constraints = SubModelConstraints(:second_submodel)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        push!(constraints, constraint)
        @test getconstraint(constraints) == Constraints(
            GraphPPL.Constraint[FactorizationConstraint(
                [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
                [
                    FactorizationConstraintEntry([
                        IndexedVariable(:x, nothing),
                        IndexedVariable(:y, nothing),
                    ]),
                ],
            ),],
        )
        @test_throws MethodError push!(constraints, "string")

        # Test 5: Test push! with FunctionalFormConstraint
        constraints = SubModelConstraints(:second_submodel)
        constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
        push!(constraints, constraint)
        @test getconstraint(constraints) == Constraints(
            GraphPPL.Constraint[FunctionalFormConstraint(
                IndexedVariable(:x, nothing),
                Normal,
            )],
        )
        @test_throws MethodError push!(constraints, "string")

        # Test 6: Test push! with MessageConstraint
        constraints = SubModelConstraints(:second_submodel)
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        push!(constraints, constraint)
        @test getconstraint(constraints) == Constraints(
            GraphPPL.Constraint[MessageConstraint(IndexedVariable(:x, nothing), Normal)],
        )
        @test_throws MethodError push!(constraints, "string")

    end

    @testset "applicable_nodes(::Model, ::Context, ::Constraint)" begin
        import GraphPPL:
            applicable_nodes,
            Constraint,
            FactorizationConstraint,
            FunctionalFormConstraint,
            MessageConstraint

        # Test 1: Test applicable_nodes with FactorizationConstraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) == [ctx[:sum_4]]

        # Test 2: Test applicable_nodes with FactorizationConstraint in vector model
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) ==
              [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 3: Test applicable_nodes with FactorizationConstraint in vector model
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) ==
              [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 4: Test applicable_nodes with FactorizationConstraint in tensor model
        model = create_tensor_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) ==
              [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 5: Test applicable_nodes with FunctionalFormConstraint

        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
        @test applicable_nodes(model, ctx, constraint) == [ctx[:x]]

        # Test 6: Test applicable_nodes with FunctionalFormConstraint in vector model

        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
        @test applicable_nodes(model, ctx, constraint) == [ctx[:x]...]

        # Test 7: Test applicable_nodes with FunctionalFormConstraint applied to a variational posterior joint

        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FunctionalFormConstraint([:x, :y], Normal)
        @test applicable_nodes(model, ctx, constraint) == [ctx[:sum_4]]

        # Test 8: Test applicable_nodes with MessageConstraint applied to a variable

        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        @test applicable_nodes(model, ctx, constraint) == [ctx[:x]]

        # Test 9: Test applicable_nodes with MessageConstraint applied to a variable in vector model

        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        @test applicable_nodes(model, ctx, constraint) == [ctx[:x]...]

        # Test 10: Test applicable_nodes with MessageConstraint applied to a variable in tensor model

        model = create_tensor_model()
        ctx = GraphPPL.getcontext(model)
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        @test applicable_nodes(model, ctx, constraint) == vec(ctx[:x])

    end

    @testset "prepare_factorization_constraint(::Context, ::FactorizationConstraint)" begin
        import GraphPPL:
            prepare_factorization_constraint,
            FactorizationConstraint,
            FactorizationConstraintEntry,
            IndexedVariable,
            FunctionalIndex,
            CombinedRange,
            SplittedRange

        # Test 1: Test prepare_factorization_constraint with normal FactorizationConstraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                    IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
                ]),
            ],
        )
        @test prepare_factorization_constraint(ctx, constraint) == constraint

        # Test 2: Test prepare_factorization_constraint with FactorizationConstraint with MeanField
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            MeanField(),
        )
        @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )

        # Test 3: Test prepare_factorization_constraint with FactorizationConstraint with FullFactorization
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            FullFactorization(),
        )
        @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )

        # Test 4: Test prepare_factorization_constraint with FactorizationConstraint with MeanField and SplittedRange output
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            MeanField(),
        )
        @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :y,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
            ],
        )

        # Test 5: Test prepare_factorization_constraint with FactorizationConstraint with MeanField on tensors
        model = create_tensor_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            MeanField(),
        )
        @test_broken prepare_factorization_constraint(ctx, constraint) ==
                     FactorizationConstraint(
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            [
                                FunctionalIndex{:begin}(firstindex),
                                FunctionalIndex{:begin}(firstindex),
                            ],
                            [
                                FunctionalIndex{:end}(lastindex),
                                FunctionalIndex{:end}(lastindex),
                            ],
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :y,
                        SplittedRange(
                            [
                                FunctionalIndex{:begin}(firstindex),
                                FunctionalIndex{:begin}(firstindex),
                            ],
                            [
                                FunctionalIndex{:end}(lastindex),
                                FunctionalIndex{:end}(lastindex),
                            ],
                        ),
                    ),
                ]),
            ],
        )
    end

    @testset "get_factorization_constraint_variables(::Context, ::FactorizationConstraintEntry)" begin
        import GraphPPL:
            get_factorization_constraint_variables,
            FactorizationConstraintEntry,
            IndexedVariable,
            FunctionalIndex,
            CombinedRange,
            SplittedRange,
            Context

        # Test 1: empty FactorizationConstraintEntry
        @test get_factorization_constraint_variables(
            Context(),
            FactorizationConstraintEntry(IndexedVariable[]),
        ) == Vector{GraphPPL.NodeLabel}[[]]

        # Test 2: Test get_factorization_constraint_variables with single variables
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        entry = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
            IndexedVariable(:out, nothing),
        ])
        @test get_factorization_constraint_variables(ctx, entry) ==
              [[ctx[:x], ctx[:y], ctx[:out]]]

        # Test 3: Test get_factorization_constraint_variables with single variables and SplittedRange
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        entry = FactorizationConstraintEntry([
            IndexedVariable(
                :x,
                SplittedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        ])
        @test get_factorization_constraint_variables(ctx, entry) == [[e] for e in ctx[:x]]

        # Test 4: Test get_factorization_constraint_variables with single variables and CombinedRange
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        entry = FactorizationConstraintEntry([
            IndexedVariable(
                :x,
                CombinedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
            IndexedVariable(
                :y,
                CombinedRange(
                    FunctionalIndex{:begin}(firstindex),
                    FunctionalIndex{:end}(lastindex),
                ),
            ),
        ])
        @test get_factorization_constraint_variables(ctx, entry) ==
              [[ctx[:x]..., ctx[:y]...]]

    end

    @testset "factorization_constraint_to_nodelabels(::Model, ::Context, ::FactorizationConstraint)" begin
        import GraphPPL:
            factorization_constraint_to_nodelabels,
            NodeLabel,
            FactorizationConstraint,
            FactorizationConstraintEntry,
            IndexedVariable,
            CombinedRange,
            SplittedRange,
            FunctionalIndex

        # Test 1: Test factorization_constraint_to_nodelabels with single variables and full factorization
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) ==
              [[NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:out, 3)]]

        # Test 2: Test factorization_constraint_to_nodelabels with single variables and MeanField
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) ==
              [[NodeLabel(:x, 1)], [NodeLabel(:y, 2)], [NodeLabel(:out, 3)]]

        # Test 3: Test factorization_constraint_to_nodelabels with vector of variables and full factorization
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) ==
              [[ctx[:x]..., ctx[:y]..., ctx[:out]]]

        # Test 4: Test factorization_constraint_to_nodelabels with vector of variables and full factorization
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) ==
              [[ctx[:x][1], ctx[:y]..., ctx[:out]]]

        # Test 5: Test factorization_constraint_to_nodelabels with tensor of variables and full factorization
        model = create_tensor_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, [1, 1]),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) ==
              [[ctx[:x][1, 1], vec(ctx[:y])..., ctx[:out]]]

        # Test 6: Test factorization_constraint_to_nodelabels with vector of variables and splitted range mean field in x
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) == [
            [ctx[:x][1]],
            [ctx[:x][2]],
            [ctx[:x][3]],
            [ctx[:x][4]],
            [ctx[:y]...],
            [ctx[:out]],
        ]

        # Test 7: Test factorization_constraint_to_nodelabels with tensor of variables and splitted range mean field in x and y
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(FunctionalIndex{:begin}(firstindex), 3),
                    ),
                    IndexedVariable(
                        :y,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) == [
            [ctx[:x][1], ctx[:y][1]],
            [ctx[:x][2], ctx[:y][2]],
            [ctx[:x][3], ctx[:y][3]],
            [ctx[:out]],
        ]

        # Test 8: Test factorization_constraint_to_nodelabels with vector of variables and combined range

        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, CombinedRange(1, 2)),
                    IndexedVariable(:y, nothing),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(3, 4))]),
            ],
        )
        @test factorization_constraint_to_nodelabels(ctx, constraint) == [
            [ctx[:x][1], ctx[:x][2], vec(ctx[:y])...],
            [ctx[:out]],
            [ctx[:x][3], ctx[:x][4]],
        ]

        # Test factorization_constraint_to_nodelabels with duplicate entries
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(1, 2))]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(2, 4))]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test_throws ErrorException factorization_constraint_to_nodelabels(ctx, constraint)

        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, SplittedRange(1, 4))]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, SplittedRange(3, 4))]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test_throws ErrorException factorization_constraint_to_nodelabels(ctx, constraint)
    end

    @testset "convert_to_bitsets(::AbstractArray, ::AbstractArray)" begin
        import GraphPPL: convert_to_bitsets, NodeLabel, BitSetTuple

        # Test 1: Test convert_to_bitsets with single variables
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables =
            [(NodeLabel(:x, 1),), (NodeLabel(:y, 2),), (NodeLabel(:z, 3),)]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])

        # Test 2: Test convert_to_bitsets with a missing variable
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables = [(NodeLabel(:x, 1),), (NodeLabel(:y, 2),)]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])

        # Test 3: Test that convert_to_bitsets returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1))]
        @test convert_to_bitsets(neighbors, fc) == BitSetTuple([
            BitSet([1]),
            BitSet([2, 3, 4]),
            BitSet([2, 3, 4]),
            BitSet([2, 3, 4]),
        ])

        # Test 4: Test that convert_to_bitsets returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1), NodeLabel(:y, 1)), (NodeLabel(:z, 1), NodeLabel(:out, 1))]
        @test convert_to_bitsets(neighbors, fc) ==
              BitSetTuple([BitSet([1, 2]), BitSet([1, 2]), BitSet([3, 4]), BitSet([3, 4])])

        # Test 5: Test that convert_to_bitsets returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1), NodeLabel(:y, 1)), (NodeLabel(:z, 1),)]
        @test convert_to_bitsets(neighbors, fc) == BitSetTuple([
            BitSet([1, 2, 4]),
            BitSet([1, 2, 4]),
            BitSet([3, 4]),
            BitSet([1, 2, 3, 4]),
        ])

        # Test 6: Test that convert_to_bitsets returns the correct factorization constraint when we have indexed statements
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:out, 1))]
        @test convert_to_bitsets(neighbors, fc) ==
              BitSetTuple([BitSet([1]), BitSet([2, 3]), BitSet([2, 3])])

        # Test 7: Test that convert_to_bitsets with empty inputs returns full joint
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = [[], []]
        @test convert_to_bitsets(neighbors, fc) ==
              BitSetTuple([BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])])

        # Test 8: Test that convert_to_bitsets with duplicates returns the least factorized constraint possible
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = [
            (NodeLabel(:x, 1),),
            (NodeLabel(:x, 1), NodeLabel(:y, 1)),
            (NodeLabel(:out, 1),),
        ]
        @test convert_to_bitsets(neighbors, fc) ==
              BitSetTuple([BitSet([1, 2]), BitSet([1, 2]), BitSet([3])])

        # Test 9: Test that convert_to_bitsets with duplicates returns the least factorized constraint possible
        neighbors = [NodeLabel(:x, 1)]
        fc = [(NodeLabel(:x, 1),), (NodeLabel(:x, 1),)]
        @test convert_to_bitsets(neighbors, fc) == BitSetTuple([BitSet([1])])

        # Test 10: Test that convert_to_bitsets with vector entries returns the correct factorization constraint for the node in question
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:x, 3)]
        fc = [
            [NodeLabel(:x, 1)],
            [NodeLabel(:x, 3)],
            [NodeLabel(:x, 6)],
            [NodeLabel(:x, 9)],
            [NodeLabel(:y, 2), NodeLabel(:y, 5), NodeLabel(:y, 8)],
        ]
        @test convert_to_bitsets(neighbors, fc) ==
              BitSetTuple([BitSet(1), BitSet(2), BitSet(3)])


        ## Exact same test set, only with array elements instead of tuples in the factorization constraints

        # Test 10: Test convert_to_bitsets with single variables
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables = [[NodeLabel(:x, 1)], [NodeLabel(:y, 2)], [NodeLabel(:z, 3)]]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])

        # Test 11: Test convert_to_bitsets with a missing variable
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables = [[NodeLabel(:x, 1)], [NodeLabel(:y, 2)]]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])

        neighbors = SVector{3}(neighbors)
        constraint_variables = SVector{2}(constraint_variables)
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])

    end

    @testset "apply!(::Model, ::Context, ::Constraint, ::AbstractArray{<:NodeLabel})" begin
        import GraphPPL:
            apply!,
            FactorizationConstraint,
            FactorizationConstraintEntry,
            SplittedRange,
            IndexedVariable,
            FunctionalIndex,
            EdgeLabel,
            FunctionalFormConstraint,
            GeneralSubModelConstraints,
            SpecificSubModelConstraints,
            Constraints,
            SubModelConstraints,
            node_options

        # Test 1: Test apply!  with a factorization constraint on a single node
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:out, nothing),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )
        apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:q] ==
              BitSetTuple([BitSet([1, 2]), BitSet([1, 2]), BitSet([3])])

        apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:q] ==
            BitSetTuple([BitSet([1, 2]), BitSet([1, 2]), BitSet([3])])

        # Test 2: Test apply!  with a splitted range constraint
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])

        # Test 3: Test apply!  with a splitted range constraint and multiple nodes
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        nodes = [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )
        apply!(model, ctx, constraint, nodes)
        @test node_options(model[nodes[1]])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])
        @test node_options(model[nodes[2]])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])
        @test node_options(model[nodes[3]])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])
        @test node_options(model[nodes[4]])[:q] ==
              BitSetTuple([BitSet([1, 2, 3]), BitSet([1, 2]), BitSet([1, 3])])

        # Test 4: Test apply! with MeanField constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            MeanField(),
        )
        apply!(model, ctx, constraint, [node])
        @test model[node].options[:q] ==
              BitSetTuple([BitSet([1, 2, 3]), BitSet([1, 2]), BitSet([1, 3])])

        # Test 5: Test apply! with MeanField constraint and multiple nodes
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        nodes = [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            MeanField(),
        )
        apply!(model, ctx, constraint, nodes)
        @test node_options(model[nodes[1]])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])
        @test node_options(model[nodes[2]])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])
        @test node_options(model[nodes[3]])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])
        @test node_options(model[nodes[4]])[:q] ==
              BitSetTuple([BitSet([1, 2, 3]), BitSet([1, 2]), BitSet([1, 3])])

        # Test 6: Test apply! with a factorization constraint with duplicate entries
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(1, 3))]),
                FactorizationConstraintEntry([
                    IndexedVariable(:x, CombinedRange(2, 3)),
                    IndexedVariable(:x, 3),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )
        @test_throws ErrorException apply!(model, ctx, constraint, [node])

        # Test 7: Test apply! with a functional form constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:x]
        constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
        apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:q] == Normal

        # Test functional form constraint applied twice

        @test_logs (
            :warn,
            "Node $node already has functional form constraint $Normal applied, therefore $Normal will not be applied",
        ) apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:q] == Normal

        # Test 8: Test apply! with GeneralSubModelConstraints
        model = create_nested_model()
        ctx = GraphPPL.getcontext(model)
        constraint = SubModelConstraints(
            submodel_with_deterministic_functions_and_anonymous_variables,
            Constraints(
                GraphPPL.Constraint[
                    FactorizationConstraint(
                        [IndexedVariable(:z, nothing), IndexedVariable(:w, nothing)],
                        [
                            FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
                            FactorizationConstraintEntry([IndexedVariable(:w, nothing)]),
                        ],
                    )
                    FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
                ],
            ),
        )
        apply!(model, ctx, constraint)
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:exp_15]],
        )[:q] == BitSetTuple([BitSet(1), BitSet(2)])
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:x]],
        )[:q] == Normal
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_4][:exp_9]],
        )[:q] == BitSetTuple([BitSet(1), BitSet(2)])
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_4][:x]],
        )[:q] == Normal

        # Test 9: Test apply! with SpecificSubModelConstraints
        model = create_nested_model()
        ctx = GraphPPL.getcontext(model)
        constraint = SubModelConstraints(
            :submodel_with_deterministic_functions_and_anonymous_variables_10,
            Constraints(
                GraphPPL.Constraint[
                    FactorizationConstraint(
                        [IndexedVariable(:z, nothing), IndexedVariable(:w, nothing)],
                        [
                            FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
                            FactorizationConstraintEntry([IndexedVariable(:w, nothing)]),
                        ],
                    )
                    FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
                ],
            ),
        )
        apply!(model, ctx, constraint)
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:exp_15]],
        )[:q] == BitSetTuple([BitSet(1), BitSet(2)])
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:x]],
        )[:q] == Normal
        @test node_options(
            model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_4][:exp_9]],
        )[:q] == BitSetTuple([BitSet([1, 2]), BitSet([1, 2])])
        @test !haskey(
            node_options(
                model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_4][:x]],
            ),
            :q,
        )

        # Test 10: Test apply! with a message constraint on an edge (variable)
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:x]
        constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
        apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:μ] == Normal

        # Test 11: Test apply! with a FunctionalFormConstraint that goes over multiple variables
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        nodes = [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]
        constraint = FunctionalFormConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            Normal,
        )
        @test_broken apply!(model, ctx, constraint, nodes)

        # Test 12: Test apply! with a FactorizationConstraint that indexes a variable on the lhs
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, 1), IndexedVariable(:x, 2)],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, 1)]),
                FactorizationConstraintEntry([IndexedVariable(:x, 2)]),
            ],
        )
        apply!(model, ctx, constraint)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])

        # Test 12: Test apply! with a FactorizationConstraint that indexes a variable on the lhs
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )
        apply!(model, ctx, constraint, [node])
        @test node_options(model[node])[:q] ==
              BitSetTuple([BitSet([1]), BitSet([2]), BitSet([3])])

        # Test 13: Test apply! with a FactorizationConstraint that has a vector with a single element on lhs
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            FunctionalIndex{:begin}(firstindex),
                            FunctionalIndex{:end}(lastindex),
                        ),
                    ),
                ]),
            ],
        )
        apply!(model, ctx, constraint)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])

        # Test 14: Test apply! with a full constraint set
        model = create_normal_model()
        constraint = Constraints([
            FactorizationConstraint(
                [
                    IndexedVariable(:w, nothing),
                    IndexedVariable(:a, nothing),
                    IndexedVariable(:b, nothing),
                ],
                [
                    FactorizationConstraintEntry([IndexedVariable(:w, nothing)]),
                    FactorizationConstraintEntry([IndexedVariable(:a, nothing)]),
                    FactorizationConstraintEntry([IndexedVariable(:b, nothing)]),
                ],
            ),
        ])
        apply!(model, constraint)
        node = model[label_for(model.graph, 5)]
        @test node_options(node)[:q] == BitSetTuple([BitSet(1), BitSet(2), BitSet(3)])

        # Test 15: Test apply! with a factorization constraint with a single entry
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [IndexedVariable(:x, nothing)],
            FactorizationConstraintEntry([
                IndexedVariable(
                    :x,
                    SplittedRange(
                        FunctionalIndex{:begin}(firstindex),
                        FunctionalIndex{:end}(lastindex),
                    ),
                ),
            ]),
        )
        apply!(model, ctx, constraint)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])

    end

    @testset "combine_factorization_constraints(::AbstractArray{<:BitSet}, ::AbstractArray{<:BitSet})" begin
        import GraphPPL: combine_factorization_constraints

        # Test 1: Test combine_factorization_constraints with single variables
        fc1 = [BitSet([1]), BitSet([2]), BitSet([3])]
        fc2 = [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]
        @test combine_factorization_constraints(fc1, fc2) ==
              [BitSet([1]), BitSet([2]), BitSet([3])]

        # Test 2: Test combine_factorization_constraints with a factorization constraint
        fc1 = [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]
        fc2 = [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]
        @test combine_factorization_constraints(fc1, fc2) ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]
        @test combine_factorization_constraints(fc2, fc1) ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

    end

    @testset "save_constraint!" begin
        import GraphPPL: save_constraint!, NodeLabel

        # Test 1: Test that save_constraint! saves a factorization constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])
        save_constraint!(model, node, constraint, :q)
        @test model[node].options[:q] == constraint

        constraint = BitSetTuple([BitSet([1, 2, 3]), BitSet([1, 2]), BitSet([1, 3])])
        save_constraint!(model, node, constraint, :q)
        @test model[node].options[:q] ==
              BitSetTuple([BitSet([1, 3]), BitSet([2]), BitSet([1, 3])])
    end

    @testset "is_valid_partition(::Set)" begin
        import GraphPPL: is_valid_partition

        # Test 1: Test that is_valid_partition returns true for a valid partition
        @test is_valid_partition(Set([BitSet([1, 2]), BitSet([3, 4])])) == true

        # Test 2: Test that is_valid_partition returns false for an invalid partition
        @test is_valid_partition(Set([BitSet([1, 2]), BitSet([2, 3])])) == false

        # Test 3: Test that is_valid_partition returns false for an invalid partition
        @test is_valid_partition(Set([BitSet([1, 2]), BitSet([2, 3]), BitSet([3, 4])])) ==
              false

        # Test 4: Test that is_valid_partition returns false for an invalid partition
        @test is_valid_partition(Set([BitSet([1, 2]), BitSet([4, 5])])) == false
    end

    @testset "materialize_constraints!(::Model)" begin
        import GraphPPL: materialize_constraints!, EdgeLabel, node_options, EdgeLabel

        # Test 1: Test materialize with a Mean Field constraint
        model = create_simple_model()
        materialize_constraints!(model)
        @test node_options(model[NodeLabel(sum, 4)])[:q] ==
              ((EdgeLabel(:out, nothing), EdgeLabel(:in, 1), EdgeLabel(:in, 2)),)

    end

    @testset "materialize_constraints!(:Model, ::NodeLabel, ::FactorNodeData)" begin
        import GraphPPL: materialize_constraints!, EdgeLabel, node_options

        # Test 1: Test materialize with a Full Factorization constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        materialize_constraints!(model, node)
        @test node_options(model[node])[:q] ==
              ((EdgeLabel(:out, nothing), EdgeLabel(:in, 1), EdgeLabel(:in, 2)),)

        # Test 2: Test materialize with a MeanField Factorization constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            (
                IndexedVariable(:x, nothing),
                IndexedVariable(:y, nothing),
                IndexedVariable(:out, nothing),
            ),
            MeanField(),
        )
        apply!(model, ctx, constraint)
        materialize_constraints!(model, node)
        @test node_options(model[node])[:q] ==
              ((EdgeLabel(:out, nothing),), (EdgeLabel(:in, 1),), (EdgeLabel(:in, 2),))
    end

    @testset "full_pipeline" begin
        import GraphPPL:
            apply!,
            FactorizationConstraint,
            materialize_constraints!,
            EdgeLabel,
            node_options,
            NodeLabel,
            FunctionalFormConstraint,
            FactorizationConstraintEntry

        # Test 1: Test that the full pipeline works with a MeanField constraint
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = Constraints(
            GraphPPL.Constraint[FactorizationConstraint(
                (
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ),
                MeanField(),
            ),],
        )
        apply!(model, ctx, constraint)
        materialize_constraints!(model)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              ((EdgeLabel(:out, nothing),), (EdgeLabel(:in, 1),), (EdgeLabel(:in, 2),))

        # Test 2: Test that the full pipeline works with a FullFactorization constraint
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = Constraints(
            GraphPPL.Constraint[FactorizationConstraint(
                (
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ),
                FullFactorization(),
            ),],
        )
        apply!(model, ctx, constraint)
        materialize_constraints!(model)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              ((EdgeLabel(:out, nothing), EdgeLabel(:in, 1), EdgeLabel(:in, 2)),)

        # Test 3: Test that the full pipeline works with a FunctionalForm constraint
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint =
            Constraints([FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)])
        apply!(model, ctx, constraint)
        materialize_constraints!(model)
        @test node_options(model[ctx[:x][1]])[:q] == Normal

        # Test 4: Test model with fixed order of indices
        model = create_normal_model()
        ctx = GraphPPL.getcontext(model)
        constraints = Constraints(
            GraphPPL.Constraint[
                FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal),
                GeneralSubModelConstraints(
                    second_submodel,
                    Constraints([
                        FactorizationConstraint(
                            (
                                IndexedVariable(:w, nothing),
                                IndexedVariable(:a, nothing),
                                IndexedVariable(:b, nothing),
                            ),
                            [
                                FactorizationConstraintEntry([
                                    IndexedVariable(:a, nothing),
                                    IndexedVariable(:b, nothing),
                                ]),
                                FactorizationConstraintEntry([
                                    IndexedVariable(:w, nothing),
                                ]),
                            ],
                        ),
                    ]),
                ),
            ],
        )
        apply!(model, ctx, constraints)
        materialize_constraints!(model)
        node = label_for(model.graph, 5)
        @test node_options(model[node])[:q] == (
            (EdgeLabel(:out, nothing),),
            (EdgeLabel(:μ, nothing), EdgeLabel(:σ, nothing)),
        )
        @test node_options(model[ctx[:x]])[:q] == Normal

    end
end

end
