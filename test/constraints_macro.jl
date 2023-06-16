module test_constraints_macro

using Test
using TestSetExtensions
using GraphPPL
using MacroTools
using StaticArrays

include("model_zoo.jl")

@testset ExtendedTestSet "constraints_macro" begin

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
    end

    @testset "applicable_nodes(::Model, ::Context, ::Constraint)" begin
        import GraphPPL:
            applicable_nodes,
            Constraint,
            FactorizationConstraint,
            FunctionalFormConstraint
        
        # Test 1: Test applicable_nodes with FactorizationConstraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y],
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
            [:x, :y],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) == [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 3: Test applicable_nodes with FactorizationConstraint in vector model
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) == [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 4: Test applicable_nodes with FactorizationConstraint in tensor model
        model = create_tensor_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, nothing),
                ]),
            ],
        )
        @test applicable_nodes(model, ctx, constraint) == [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]
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
            [:x, :y],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
                    IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
                ]),
            ],
        )
        @test prepare_factorization_constraint(ctx, constraint) == constraint

        # Test 2: Test prepare_factorization_constraint with FactorizationConstraint with MeanField
        constraint = FactorizationConstraint([:x, :y], MeanField())
        @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [:x, :y],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )

        # Test 3: Test prepare_factorization_constraint with FactorizationConstraint with FullFactorization
        constraint = FactorizationConstraint([:x, :y], FullFactorization())
        @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [:x, :y],
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
        constraint = FactorizationConstraint([:x, :y], MeanField())
        @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [:x, :y],
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
        constraint = FactorizationConstraint([:x, :y], MeanField())
        @test_broken prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
            [:x, :y],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :x,
                        SplittedRange(
                            [FunctionalIndex{:begin}(firstindex), FunctionalIndex{:begin}(firstindex)],
                            [FunctionalIndex{:end}(lastindex), FunctionalIndex{:end}(lastindex)],
                        ),
                    ),
                ]),
                FactorizationConstraintEntry([
                    IndexedVariable(
                        :y,
                        SplittedRange(
                            [FunctionalIndex{:begin}(firstindex), FunctionalIndex{:begin}(firstindex)],
                            [FunctionalIndex{:end}(lastindex), FunctionalIndex{:end}(lastindex)],
                        ),
                    ),
                ]),
            ],
        )
    end

    @testset "get_variables(::Context, ::FactorizationConstraintEntry)" begin
        import GraphPPL:
            get_variables,
            FactorizationConstraintEntry,
            IndexedVariable,
            FunctionalIndex,
            CombinedRange,
            SplittedRange

        # Test 1: Test get_variables with single variables
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        entry = FactorizationConstraintEntry([
            IndexedVariable(:x, nothing),
            IndexedVariable(:y, nothing),
            IndexedVariable(:out, nothing),
        ])
        @test get_variables(ctx, entry) == [[ctx[:x], ctx[:y], ctx[:out]]]
    end

    @testset "convert_to_nodelabels(::Model, ::Context, ::FactorizationConstraint)" begin
        import GraphPPL:
            convert_to_nodelabels,
            NodeLabel,
            FactorizationConstraint,
            FactorizationConstraintEntry,
            IndexedVariable,
            CombinedRange,
            SplittedRange,
            FunctionalIndex

        # Test 1: Test convert_to_nodelabels with single variables and full factorization
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test convert_to_nodelabels(ctx, constraint) ==
              [[NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:out, 3)]]

        # Test 2: Test convert_to_nodelabels with single variables and MeanField
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test convert_to_nodelabels(ctx, constraint) ==
              [[NodeLabel(:x, 1)], [NodeLabel(:y, 2)], [NodeLabel(:out, 3)]]

        # Test 3: Test convert_to_nodelabels with vector of variables and full factorization
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, nothing),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test convert_to_nodelabels(ctx, constraint) ==
              [[ctx[:x]..., ctx[:y]..., ctx[:out]]]

        # Test 4: Test convert_to_nodelabels with vector of variables and full factorization
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, 1),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test convert_to_nodelabels(ctx, constraint) ==
              [[ctx[:x][1], ctx[:y]..., ctx[:out]]]

        # Test 5: Test convert_to_nodelabels with tensor of variables and full factorization
        model = create_tensor_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, [1, 1]),
                    IndexedVariable(:y, nothing),
                    IndexedVariable(:out, nothing),
                ]),
            ],
        )
        @test convert_to_nodelabels(ctx, constraint) ==
              [[ctx[:x][1, 1], vec(ctx[:y])..., ctx[:out]]]

        # Test 6: Test convert_to_nodelabels with vector of variables and splitted range mean field in x
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
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
        @test convert_to_nodelabels(ctx, constraint) == [
            [ctx[:x][1]],
            [ctx[:x][2]],
            [ctx[:x][3]],
            [ctx[:x][4]],
            [ctx[:y]...],
            [ctx[:out]],
        ]

        # Test 7: Test convert_to_nodelabels with tensor of variables and splitted range mean field in x and y
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
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
        @test convert_to_nodelabels(ctx, constraint) == [
            [ctx[:x][1], ctx[:y][1]],
            [ctx[:x][2], ctx[:y][2]],
            [ctx[:x][3], ctx[:y][3]],
            [ctx[:out]],
        ]

        # Test 8: Test convert_to_nodelabels with vector of variables and combined range

        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([
                    IndexedVariable(:x, CombinedRange(1, 2)),
                    IndexedVariable(:y, nothing),
                ]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(3, 4))]),
            ],
        )
        @test convert_to_nodelabels(ctx, constraint) == [
            [ctx[:x][1], ctx[:x][2], vec(ctx[:y])...],
            [ctx[:out]],
            [ctx[:x][3], ctx[:x][4]],
        ]

        # Test convert_to_nodelabels with duplicate entries
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test_throws ErrorException convert_to_nodelabels(ctx, constraint)

        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(1, 2))]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, CombinedRange(2, 4))]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test_throws ErrorException convert_to_nodelabels(ctx, constraint)

        constraint = FactorizationConstraint(
            [:x, :y, :out],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, SplittedRange(1, 4))]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:x, SplittedRange(3, 4))]),
                FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
            ],
        )
        @test_throws ErrorException convert_to_nodelabels(ctx, constraint)
    end

    @testset "convert_to_bitsets(::AbstractArray, ::AbstractArray)" begin
        import GraphPPL: convert_to_bitsets, NodeLabel

        # Test 1: Test convert_to_bitsets with single variables
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables =
            [(NodeLabel(:x, 1),), (NodeLabel(:y, 2),), (NodeLabel(:z, 3),)]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              [BitSet([1]), BitSet([2]), BitSet([3])]

        # Test 2: Test convert_to_bitsets with a missing variable
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables = [(NodeLabel(:x, 1),), (NodeLabel(:y, 2),)]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 3: Test that convert_to_bitsets returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1))]
        @test convert_to_bitsets(neighbors, fc) ==
              [BitSet([1]), BitSet([2, 3, 4]), BitSet([2, 3, 4]), BitSet([2, 3, 4])]

        # Test 4: Test that convert_to_bitsets returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1), NodeLabel(:y, 1)), (NodeLabel(:z, 1), NodeLabel(:out, 1))]
        @test convert_to_bitsets(neighbors, fc) ==
              [BitSet([1, 2]), BitSet([1, 2]), BitSet([3, 4]), BitSet([3, 4])]

        # Test 5: Test that convert_to_bitsets returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1), NodeLabel(:y, 1)), (NodeLabel(:z, 1),)]
        @test convert_to_bitsets(neighbors, fc) ==
              [BitSet([1, 2, 4]), BitSet([1, 2, 4]), BitSet([3, 4]), BitSet([1, 2, 3, 4])]

        # Test 6: Test that convert_to_bitsets returns the correct factorization constraint when we have indexed statements
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = [(NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:out, 1))]
        @test convert_to_bitsets(neighbors, fc) ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]

        # Test 7: Test that convert_to_bitsets with empty inputs returns full joint
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = [[], []]
        @test convert_to_bitsets(neighbors, fc) ==
              [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]

        # Test 8: Test that convert_to_bitsets with duplicates returns the least factorized constraint possible
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = [
            (NodeLabel(:x, 1),),
            (NodeLabel(:x, 1), NodeLabel(:y, 1)),
            (NodeLabel(:out, 1),),
        ]
        @test convert_to_bitsets(neighbors, fc) ==
              [BitSet([1, 2]), BitSet([1, 2]), BitSet([3])]

        # Test 9: Test that convert_to_bitsets with duplicates returns the least factorized constraint possible
        neighbors = [NodeLabel(:x, 1)]
        fc = [(NodeLabel(:x, 1),), (NodeLabel(:x, 1),)]
        @test convert_to_bitsets(neighbors, fc) == [BitSet([1])]

        # Test 10: Test that convert_to_bitsets with vector entries returns the correct factorization constraint for the node in question
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:x, 3)]
        fc = [
            [NodeLabel(:x, 1)],
            [NodeLabel(:x, 3)],
            [NodeLabel(:x, 6)],
            [NodeLabel(:x, 9)],
            [NodeLabel(:y, 2), NodeLabel(:y, 5), NodeLabel(:y, 8)],
        ]
        @test convert_to_bitsets(neighbors, fc) == [BitSet(1), BitSet(2), BitSet(3)]


        ## Exact same test set, only with array elements instead of tuples in the factorization constraints

        # Test 10: Test convert_to_bitsets with single variables
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables = [[NodeLabel(:x, 1)], [NodeLabel(:y, 2)], [NodeLabel(:z, 3)]]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              [BitSet([1]), BitSet([2]), BitSet([3])]

        # Test 11: Test convert_to_bitsets with a missing variable
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 2), NodeLabel(:z, 3)]
        constraint_variables = [[NodeLabel(:x, 1)], [NodeLabel(:y, 2)]]
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        neighbors = SVector{3}(neighbors)
        constraint_variables = SVector{2}(constraint_variables)
        @test convert_to_bitsets(neighbors, constraint_variables) ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

    end

    @testset "apply!(::Model, ::Context, ::Constraint, ::AbstractArray{<:NodeLabel})" begin
        import GraphPPL:
            apply!,
            FactorizationConstraint,
            FactorizationConstraintEntry,
            SplittedRange,
            IndexedVariable,
            FunctionalIndex,
            EdgeLabel

        # Test 1: Test apply!  with a factorization constraint on a single node
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [:x, :y],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )
        apply!(model, ctx, constraint, [node])
        @test model[node].options[:q] ==
              BitSet[BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 2: Test apply!  with a splitted range constraint
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [:x, :y],
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

        # Test 3: Test apply!  with a splitted range constraint and multiple nodes
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        nodes = [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]
        constraint = FactorizationConstraint(
            [:x, :y],
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
        @test model[nodes[1]].options[:q] == BitSet[BitSet([1]), BitSet([2]), BitSet([3])]
        @test model[nodes[2]].options[:q] == BitSet[BitSet([1]), BitSet([2]), BitSet([3])]
        @test model[nodes[3]].options[:q] == BitSet[BitSet([1]), BitSet([2]), BitSet([3])]
        @test model[nodes[4]].options[:q] ==
              BitSet[BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 4: Test apply! with MeanField constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint([:x, :y], MeanField())
        apply!(model, ctx, constraint, [node])
        @test model[node].options[:q] ==
              BitSet[BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 5: Test apply! with MeanField constraint and multiple nodes
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        nodes = [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]
        constraint = FactorizationConstraint([:x, :y], MeanField())
        apply!(model, ctx, constraint, nodes)
        @test model[nodes[1]].options[:q] == BitSet[BitSet([1]), BitSet([2]), BitSet([3])]
        @test model[nodes[2]].options[:q] == BitSet[BitSet([1]), BitSet([2]), BitSet([3])]
        @test model[nodes[3]].options[:q] == BitSet[BitSet([1]), BitSet([2]), BitSet([3])]
        @test model[nodes[4]].options[:q] ==
              BitSet[BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 6: Test apply! with a factorization constraint with duplicate entries
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = FactorizationConstraint(
            [:x, :y],
            [
                FactorizationConstraintEntry([IndexedVariable(:x, 1)]),
                FactorizationConstraintEntry([IndexedVariable(:x, 1), IndexedVariable(:x, 3)]),
                FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
            ],
        )
        @test_throws ErrorException apply!(model, ctx, constraint, [node])
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
        constraint = [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]
        save_constraint!(model, node, constraint)
        @test model[node].options[:q] == constraint

        constraint = [BitSet([1, 2, 3]), BitSet([1, 2]), BitSet([1, 3])]
        save_constraint!(model, node, constraint)
        @test model[node].options[:q] == [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]

        # Test 2: Test that save_constraint! saves a MeanField constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = Tuple([
            (model[node, neighbor],) for neighbor in GraphPPL.neighbors(model, node)
        ])
        save_constraint!(model, node, constraint)
        @test model[node].options[:q] == constraint

        # Test 3: Test that save_constraint! saves a FullFactorization constraint
        model = create_simple_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_4]
        constraint = (
            Tuple([model[node, neighbor] for neighbor in GraphPPL.neighbors(model, node)]),
        )
        save_constraint!(model, node, constraint)
        @test model[node].options[:q] == constraint


    end
end

end
