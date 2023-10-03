module test_constraints_engine

using Test
using TestSetExtensions
using GraphPPL
using MacroTools
using StaticArrays
using MetaGraphsNext
using BitSetTuples

include("model_zoo.jl")

@testset ExtendedTestSet "constraints_engine" begin

    # @testset "FactorizationConstraintEntry" begin
    #     import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    #     # Test 1: Test FactorisationConstraintEntry
    #     @test FactorizationConstraintEntry([
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:y, nothing),
    #     ]) isa FactorizationConstraintEntry

    #     a = FactorizationConstraintEntry([
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:y, nothing),
    #     ])
    #     b = FactorizationConstraintEntry([
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:y, nothing),
    #     ])
    #     @test a == b
    #     c = FactorizationConstraintEntry([
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:y, nothing),
    #         IndexedVariable(:z, nothing),
    #     ])
    #     @test a != c
    #     d = FactorizationConstraintEntry([
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:p, nothing),
    #     ])
    #     @test a != d

    #     # Test 2: Test FactorisationConstraintEntry with mixed IndexedVariable types
    #     a = FactorizationConstraintEntry([
    #         IndexedVariable(:x, 1),
    #         IndexedVariable(:y, nothing),
    #     ])
    # end

    # @testset "CombinedRange" begin
    #     import GraphPPL: CombinedRange, is_splitted, FunctionalIndex
    #     for left = 1:3, right = 5:8
    #         cr = CombinedRange(left, right)

    #         @test firstindex(cr) === left
    #         @test lastindex(cr) === right
    #         @test !is_splitted(cr)
    #         @test length(cr) === lastindex(cr) - firstindex(cr) + 1

    #         for i = left:right
    #             @test i ∈ cr
    #             @test !((i + lastindex(cr) + 1) ∈ cr)
    #         end
    #     end
    #     range = CombinedRange(
    #         FunctionalIndex{:begin}(firstindex),
    #         FunctionalIndex{:end}(lastindex),
    #     )
    #     @test firstindex(range).f === firstindex
    #     @test lastindex(range).f === lastindex
    #     @test_throws MethodError length(range)
    # end

    # @testset "SplittedRange" begin
    #     import GraphPPL: SplittedRange, is_splitted, FunctionalIndex
    #     for left = 1:3, right = 5:8
    #         cr = SplittedRange(left, right)

    #         @test firstindex(cr) === left
    #         @test lastindex(cr) === right
    #         @test is_splitted(cr)
    #         @test length(cr) === lastindex(cr) - firstindex(cr) + 1

    #         for i = left:right
    #             @test i ∈ cr
    #             @test !((i + lastindex(cr) + 1) ∈ cr)
    #         end
    #     end
    #     range = SplittedRange(
    #         FunctionalIndex{:begin}(firstindex),
    #         FunctionalIndex{:end}(lastindex),
    #     )
    #     @test firstindex(range).f === firstindex
    #     @test lastindex(range).f === lastindex
    #     @test_throws MethodError length(range)
    # end

    # @testset "__factorization_specification_resolve_index" begin
    #     import GraphPPL:
    #         __factorization_specification_resolve_index,
    #         FunctionalIndex,
    #         CombinedRange,
    #         SplittedRange,
    #         NodeLabel,
    #         ResizableArray

    #     collection = ResizableArray(NodeLabel, Val(1))
    #     for i = 1:10
    #         collection[i] = NodeLabel(:x, i)
    #     end

    #     # Test 1: Test __factorization_specification_resolve_index with FunctionalIndex
    #     index = FunctionalIndex{:begin}(firstindex)
    #     @test __factorization_specification_resolve_index(index, collection) ===
    #           firstindex(collection)

    #     @test_throws ErrorException __factorization_specification_resolve_index(
    #         index,
    #         collection[1],
    #     )

    #     # Test 2: Test __factorization_specification_resolve_index with CombinedRange
    #     index = CombinedRange(1, 5)
    #     @test __factorization_specification_resolve_index(index, collection) === index
    #     index = CombinedRange(
    #         FunctionalIndex{:begin}(firstindex),
    #         FunctionalIndex{:end}(lastindex),
    #     )
    #     @test __factorization_specification_resolve_index(index, collection) ===
    #           CombinedRange(1, 10)
    #     index = CombinedRange(5, FunctionalIndex{:end}(lastindex))
    #     @test __factorization_specification_resolve_index(index, collection) ===
    #           CombinedRange(5, 10)
    #     index = CombinedRange(1, 20)
    #     @test_throws ErrorException __factorization_specification_resolve_index(
    #         index,
    #         collection,
    #     )

    #     @test_throws ErrorException __factorization_specification_resolve_index(
    #         index,
    #         collection[1],
    #     )

    #     # Test 3: Test __factorization_specification_resolve_index with SplittedRange
    #     index = SplittedRange(1, 5)
    #     @test __factorization_specification_resolve_index(index, collection) === index
    #     index = SplittedRange(
    #         FunctionalIndex{:begin}(firstindex),
    #         FunctionalIndex{:end}(lastindex),
    #     )
    #     @test __factorization_specification_resolve_index(index, collection) ===
    #           SplittedRange(1, 10)
    #     index = SplittedRange(5, FunctionalIndex{:end}(lastindex))
    #     @test __factorization_specification_resolve_index(index, collection) ===
    #           SplittedRange(5, 10)
    #     index = SplittedRange(1, 20)
    #     @test_throws ErrorException __factorization_specification_resolve_index(
    #         index,
    #         collection,
    #     )

    #     @test_throws ErrorException __factorization_specification_resolve_index(
    #         index,
    #         collection[1],
    #     )

    #     # Test 4: Test __factorization_specification_resolve_index with Array of indices
    #     index = SplittedRange(
    #         [FunctionalIndex{:begin}(firstindex), FunctionalIndex{:begin}(firstindex)],
    #         [FunctionalIndex{:end}(lastindex), FunctionalIndex{:end}(lastindex)],
    #     )
    #     collection = GraphPPL.ResizableArray(GraphPPL.NodeLabel, Val(2))
    #     for i = 1:3
    #         for j = 1:5
    #             collection[i, j] = GraphPPL.NodeLabel(:x, i * j)
    #         end
    #     end

    #     #@bvdmitri we should check if we should allow this at all (i.e. x[begin, begin]..x[end, end]), otherwise we can delete these broken tests and just disallow in general. I remember you saying this isn't possible, but I don't remember if it referenced this exact problem.

    #     @test_broken __factorization_specification_resolve_index(index, collection) ===
    #                  SplittedRange([1, 1], [3, 5])
    # end

    # @testset "factorization_split" begin
    #     import GraphPPL:
    #         factorization_split,
    #         FactorizationConstraintEntry,
    #         IndexedVariable,
    #         FunctionalIndex,
    #         CombinedRange,
    #         SplittedRange

    #     # Test 1: Test factorization_split with single split
    #     @test factorization_split(
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #             ]),
    #         ],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
    #             ]),
    #         ],
    #     ) == [
    #         FactorizationConstraintEntry([
    #             IndexedVariable(
    #                 :x,
    #                 SplittedRange(
    #                     FunctionalIndex{:begin}(firstindex),
    #                     FunctionalIndex{:end}(lastindex),
    #                 ),
    #             ),
    #         ]),
    #     ]
    #     @test factorization_split(
    #         [
    #             FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #             ]),
    #         ],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
    #             ]),
    #             FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
    #         ],
    #     ) == [
    #         FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #         FactorizationConstraintEntry([
    #             IndexedVariable(
    #                 :x,
    #                 SplittedRange(
    #                     FunctionalIndex{:begin}(firstindex),
    #                     FunctionalIndex{:end}(lastindex),
    #                 ),
    #             ),
    #         ]),
    #         FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
    #     ]
    #     @test factorization_split(
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #                 IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
    #             ]),
    #         ],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
    #                 IndexedVariable(:y, FunctionalIndex{:end}(lastindex)),
    #             ]),
    #         ],
    #     ) == [
    #         FactorizationConstraintEntry([
    #             IndexedVariable(
    #                 :x,
    #                 SplittedRange(
    #                     FunctionalIndex{:begin}(firstindex),
    #                     FunctionalIndex{:end}(lastindex),
    #                 ),
    #             ),
    #             IndexedVariable(
    #                 :y,
    #                 SplittedRange(
    #                     FunctionalIndex{:begin}(firstindex),
    #                     FunctionalIndex{:end}(lastindex),
    #                 ),
    #             ),
    #         ]),
    #     ]

    #     # Test factorization_split with only FactorizationConstraintEntrys
    #     @test factorization_split(
    #         FactorizationConstraintEntry([
    #             IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #             IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
    #         ]),
    #         FactorizationConstraintEntry([
    #             IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
    #             IndexedVariable(:y, FunctionalIndex{:end}(lastindex)),
    #         ]),
    #     ) == FactorizationConstraintEntry([
    #         IndexedVariable(
    #             :x,
    #             SplittedRange(
    #                 FunctionalIndex{:begin}(firstindex),
    #                 FunctionalIndex{:end}(lastindex),
    #             ),
    #         ),
    #         IndexedVariable(
    #             :y,
    #             SplittedRange(
    #                 FunctionalIndex{:begin}(firstindex),
    #                 FunctionalIndex{:end}(lastindex),
    #             ),
    #         ),
    #     ])

    #     # Test mixed behaviour 
    #     @test factorization_split(
    #         [
    #             FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #             ]),
    #         ],
    #         FactorizationConstraintEntry([
    #             IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
    #         ]),
    #     ) == [
    #         FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #         FactorizationConstraintEntry([
    #             IndexedVariable(
    #                 :x,
    #                 SplittedRange(
    #                     FunctionalIndex{:begin}(firstindex),
    #                     FunctionalIndex{:end}(lastindex),
    #                 ),
    #             ),
    #         ]),
    #     ]

    #     @test factorization_split(
    #         FactorizationConstraintEntry([
    #             IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #         ]),
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),
    #             ]),
    #             FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
    #         ],
    #     ) == [
    #         FactorizationConstraintEntry([
    #             IndexedVariable(
    #                 :x,
    #                 SplittedRange(
    #                     FunctionalIndex{:begin}(firstindex),
    #                     FunctionalIndex{:end}(lastindex),
    #                 ),
    #             ),
    #         ]),
    #         FactorizationConstraintEntry([IndexedVariable(:z, nothing)]),
    #     ]
    # end

    # @testset "FactorizationConstraint" begin
    #     import GraphPPL:
    #         FactorizationConstraint,
    #         FactorizationConstraintEntry,
    #         IndexedVariable,
    #         FunctionalIndex,
    #         CombinedRange,
    #         SplittedRange

    #     # Test 1: Test FactorizationConstraint with single variables
    #     @test FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     ) isa Any
    #     @test FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
    #             FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #         ],
    #     ) isa Any
    #     @test_throws ErrorException FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [FactorizationConstraintEntry([IndexedVariable(:x, nothing)])],
    #     )
    #     @test_throws ErrorException FactorizationConstraint(
    #         [IndexedVariable(:x, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )

    #     # Test 2: Test FactorizationConstraint with indexed variables
    #     @test FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, 1),
    #                 IndexedVariable(:y, 1),
    #             ]),
    #         ],
    #     ) isa Any
    #     @test FactorizationConstraint(
    #         [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
    #         [
    #             FactorizationConstraintEntry([IndexedVariable(:x, 1)]),
    #             FactorizationConstraintEntry([IndexedVariable(:y, 1)]),
    #         ],
    #     ) isa Any
    #     @test_throws ErrorException FactorizationConstraint(
    #         [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
    #         [FactorizationConstraintEntry([IndexedVariable(:x, 1)])],
    #     )
    #     @test_throws ErrorException FactorizationConstraint(
    #         [IndexedVariable(:x, 1)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, 1),
    #                 IndexedVariable(:y, 1),
    #             ]),
    #         ],
    #     )

    #     # Test 3: Test FactorizationConstraint with SplittedRanges
    #     @test FactorizationConstraint(
    #         [IndexedVariable(:x, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :x,
    #                     SplittedRange(
    #                         FunctionalIndex{:begin}(firstindex),
    #                         FunctionalIndex{:end}(lastindex),
    #                     ),
    #                 ),
    #             ]),
    #         ],
    #     ) isa Any
    #     @test_throws ErrorException FactorizationConstraint(
    #         [IndexedVariable(:x, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :x,
    #                     SplittedRange(
    #                         FunctionalIndex{:begin}(firstindex),
    #                         FunctionalIndex{:end}(lastindex),
    #                     ),
    #                 ),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )

    #     # Test 4: Test FactorizationConstraint with CombinedRanges
    #     @test FactorizationConstraint(
    #         [IndexedVariable(:x, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :x,
    #                     CombinedRange(
    #                         FunctionalIndex{:begin}(firstindex),
    #                         FunctionalIndex{:end}(lastindex),
    #                     ),
    #                 ),
    #             ]),
    #         ],
    #     ) isa Any
    #     @test_throws ErrorException FactorizationConstraint(
    #         [IndexedVariable(:x, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :x,
    #                     CombinedRange(
    #                         FunctionalIndex{:begin}(firstindex),
    #                         FunctionalIndex{:end}(lastindex),
    #                     ),
    #                 ),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )

    #     # Test 5: Test FactorizationConstraint  with duplicate entries
    #     @test_throws ErrorException constraint = FactorizationConstraint(
    #         [
    #             IndexedVariable(:x, nothing),
    #             IndexedVariable(:y, nothing),
    #             IndexedVariable(:out, nothing),
    #         ],
    #         [
    #             FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
    #             FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
    #             FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #             FactorizationConstraintEntry([IndexedVariable(:out, nothing)]),
    #         ],
    #     )
    # end

    # @testset "multiply(::FactorisationConstraintEntry, ::FactorisationConstraintEntry)" begin
    #     import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    #     entry = FactorizationConstraintEntry([
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:y, nothing),
    #     ])
    #     x = entry
    #     for i = 1:3
    #         x = x * x
    #         @test x == [entry for _ = 1:(2^i)]
    #     end
    # end

    # @testset "push!(::Constraints, ::Constraint)" begin
    #     import GraphPPL:
    #         Constraints,
    #         Constraint,
    #         FactorizationConstraint,
    #         FunctionalFormConstraint,
    #         MessageConstraint,
    #         SpecificSubModelConstraints,
    #         GeneralSubModelConstraints,
    #         IndexedVariable

    #     # Test 1: Test push! with FactorizationConstraint
    #     constraints = Constraints()
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ],),
    #         ],
    #     )
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:y, nothing), IndexedVariable(:x, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )
    #     @test_throws ErrorException push!(constraints, constraint)

    #     # Test 2: Test push! with FunctionalFormConstraint
    #     constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    #     constraint = FunctionalFormConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         Normal,
    #     )
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    #     constraint = FunctionalFormConstraint(IndexedVariable(:x, 1), Normal)
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    #     constraint = FunctionalFormConstraint(
    #         [IndexedVariable(:x, 1), IndexedVariable(:y, 1)],
    #         Normal,
    #     )
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)

    #     constraint = FunctionalFormConstraint(
    #         [IndexedVariable(:y, 1), IndexedVariable(:x, 1)],
    #         Normal,
    #     )
    #     @test_broken @test_throws ErrorException push!(constraints, constraint)

    #     # Test 3: Test push! with MessageConstraint
    #     constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    #     constraint = MessageConstraint(IndexedVariable(:x, 2), Normal)
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)

    #     # Test 4: Test push! with SpecificSubModelConstraints
    #     constraint = SpecificSubModelConstraints(:first_submodel_3, Constraints())
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)

    #     # Test 5: Test push! with GeneralSubModelConstraints
    #     constraint = GeneralSubModelConstraints(gcv, Constraints())
    #     push!(constraints, constraint)
    #     @test_throws ErrorException push!(constraints, constraint)
    # end

    # @testset "push!(::SubModelConstraints, c::Constraint)" begin
    #     import GraphPPL:
    #         SubModelConstraints,
    #         Constraint,
    #         FactorizationConstraint,
    #         FunctionalFormConstraint,
    #         MessageConstraint,
    #         getconstraint,
    #         Constraints

    #     # Test 1: Test push! with FactorizationConstraint
    #     constraints = SubModelConstraints(gcv)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )
    #     push!(constraints, constraint)
    #     @test getconstraint(constraints) == Constraints(
    #         GraphPPL.Constraint[FactorizationConstraint(
    #             [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #             [
    #                 FactorizationConstraintEntry([
    #                     IndexedVariable(:x, nothing),
    #                     IndexedVariable(:y, nothing),
    #                 ]),
    #             ],
    #         ),],
    #     )
    #     @test_throws MethodError push!(constraints, "string")

    #     # Test 2: Test push! with FunctionalFormConstraint
    #     constraints = SubModelConstraints(gcv)
    #     constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
    #     push!(constraints, constraint)
    #     @test getconstraint(constraints) == Constraints(
    #         GraphPPL.Constraint[FunctionalFormConstraint(
    #             IndexedVariable(:x, nothing),
    #             Normal,
    #         )],
    #     )
    #     @test_throws MethodError push!(constraints, "string")

    #     # Test 3: Test push! with MessageConstraint
    #     constraints = SubModelConstraints(gcv)
    #     constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
    #     push!(constraints, constraint)
    #     @test getconstraint(constraints) == Constraints(
    #         GraphPPL.Constraint[MessageConstraint(IndexedVariable(:x, nothing), Normal)],
    #     )
    #     @test_throws MethodError push!(constraints, "string")

    #     # Test 4: Test push! with SpecificSubModelConstraints
    #     constraints = SubModelConstraints(:gcv_3)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )
    #     push!(constraints, constraint)
    #     @test getconstraint(constraints) == Constraints(
    #         GraphPPL.Constraint[FactorizationConstraint(
    #             [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #             [
    #                 FactorizationConstraintEntry([
    #                     IndexedVariable(:x, nothing),
    #                     IndexedVariable(:y, nothing),
    #                 ]),
    #             ],
    #         ),],
    #     )
    #     @test_throws MethodError push!(constraints, "string")

    #     # Test 5: Test push! with FunctionalFormConstraint
    #     constraints = SubModelConstraints(:second_submodel)
    #     constraint = FunctionalFormConstraint(IndexedVariable(:x, nothing), Normal)
    #     push!(constraints, constraint)
    #     @test getconstraint(constraints) == Constraints(
    #         GraphPPL.Constraint[FunctionalFormConstraint(
    #             IndexedVariable(:x, nothing),
    #             Normal,
    #         )],
    #     )
    #     @test_throws MethodError push!(constraints, "string")

    #     # Test 6: Test push! with MessageConstraint
    #     constraints = SubModelConstraints(:second_submodel)
    #     constraint = MessageConstraint(IndexedVariable(:x, nothing), Normal)
    #     push!(constraints, constraint)
    #     @test getconstraint(constraints) == Constraints(
    #         GraphPPL.Constraint[MessageConstraint(IndexedVariable(:x, nothing), Normal)],
    #     )
    #     @test_throws MethodError push!(constraints, "string")

    # end

    # @testset "prepare_factorization_constraint(::Context, ::FactorizationConstraint)" begin
    #     import GraphPPL:
    #         prepare_factorization_constraint,
    #         FactorizationConstraint,
    #         FactorizationConstraintEntry,
    #         IndexedVariable,
    #         FunctionalIndex,
    #         CombinedRange,
    #         SplittedRange

    #     # Test 1: Test prepare_factorization_constraint with normal FactorizationConstraint
    #     model = create_terminated_model(simple_model)
    #     ctx = GraphPPL.getcontext(model)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),
    #                 IndexedVariable(:y, FunctionalIndex{:begin}(firstindex)),
    #             ]),
    #         ],
    #     )
    #     @test prepare_factorization_constraint(ctx, constraint) == constraint

    #     # Test 2: Test prepare_factorization_constraint with FactorizationConstraint with MeanField
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         MeanField(),
    #     )
    #     @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([IndexedVariable(:x, nothing)]),
    #             FactorizationConstraintEntry([IndexedVariable(:y, nothing)]),
    #         ],
    #     )

    #     # Test 3: Test prepare_factorization_constraint with FactorizationConstraint with FullFactorization
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         FullFactorization(),
    #     )
    #     @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(:x, nothing),
    #                 IndexedVariable(:y, nothing),
    #             ]),
    #         ],
    #     )

    #     # Test 4: Test prepare_factorization_constraint with FactorizationConstraint with MeanField and SplittedRange output
    #     model = create_terminated_model(vector_model)
    #     ctx = GraphPPL.getcontext(model)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         MeanField(),
    #     )
    #     @test prepare_factorization_constraint(ctx, constraint) == FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :x,
    #                     SplittedRange(
    #                         FunctionalIndex{:begin}(firstindex),
    #                         FunctionalIndex{:end}(lastindex),
    #                     ),
    #                 ),
    #             ]),
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :y,
    #                     SplittedRange(
    #                         FunctionalIndex{:begin}(firstindex),
    #                         FunctionalIndex{:end}(lastindex),
    #                     ),
    #                 ),
    #             ]),
    #         ],
    #     )

    #     # Test 5: Test prepare_factorization_constraint with FactorizationConstraint with MeanField on tensors
    #     model = create_terminated_model(tensor_model)
    #     ctx = GraphPPL.getcontext(model)
    #     constraint = FactorizationConstraint(
    #         [IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)],
    #         MeanField(),
    #     )
    #     @test_broken prepare_factorization_constraint(ctx, constraint) ==
    #                  FactorizationConstraint(
    #         IndexedVariable(:x, nothing),
    #         IndexedVariable(:y, nothing),
    #         [
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :x,
    #                     SplittedRange(
    #                         [
    #                             FunctionalIndex{:begin}(firstindex),
    #                             FunctionalIndex{:begin}(firstindex),
    #                         ],
    #                         [
    #                             FunctionalIndex{:end}(lastindex),
    #                             FunctionalIndex{:end}(lastindex),
    #                         ],
    #                     ),
    #                 ),
    #             ]),
    #             FactorizationConstraintEntry([
    #                 IndexedVariable(
    #                     :y,
    #                     SplittedRange(
    #                         [
    #                             FunctionalIndex{:begin}(firstindex),
    #                             FunctionalIndex{:begin}(firstindex),
    #                         ],
    #                         [
    #                             FunctionalIndex{:end}(lastindex),
    #                             FunctionalIndex{:end}(lastindex),
    #                         ],
    #                     ),
    #                 ),
    #             ]),
    #         ],
    #     )
    # end

    # @testset "combine_factorization_constraints(::AbstractArray{<:BitSet}, ::AbstractArray{<:BitSet})" begin
    #     import GraphPPL: combine_factorization_constraints

    #     # Test 1: Test combine_factorization_constraints with single variables
    #     fc1 = [BitSet([1]), BitSet([2]), BitSet([3])]
    #     fc2 = [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]
    #     @test combine_factorization_constraints(fc1, fc2) ==
    #           [BitSet([1]), BitSet([2]), BitSet([3])]

    #     # Test 2: Test combine_factorization_constraints with a factorization constraint
    #     fc1 = [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]
    #     fc2 = [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]
    #     @test combine_factorization_constraints(fc1, fc2) ==
    #           [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]
    #     @test combine_factorization_constraints(fc2, fc1) ==
    #           [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

    # end

    # @testset "save_constraint!" begin
    #     import GraphPPL: save_constraint!, NodeLabel, neighbors, factorization_constraint

    #     # Test 1: Test that save_constraint! saves a factorization constraint
    #     model = create_terminated_model(simple_model)
    #     ctx = GraphPPL.getcontext(model)
    #     node = first(neighbors(model, ctx[:z]))
    #     constraint = BitSetTuple([BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])])
    #     save_constraint!(model, node, constraint, :q)
    #     @test factorization_constraint(model[node]) == constraint

    #     constraint = BitSetTuple([BitSet([1, 2, 3]), BitSet([1, 2]), BitSet([1, 3])])
    #     save_constraint!(model, node, constraint, :q)
    #     @test factorization_constraint(model[node]) ==
    #           BitSetTuple([BitSet([1, 3]), BitSet([2]), BitSet([1, 3])])
    # end

    # @testset "is_valid_partition(::Set)" begin
    #     import GraphPPL: is_valid_partition

    #     # Test 1: Test that is_valid_partition returns true for a valid partition
    #     @test is_valid_partition(Set([BitSet([1, 2]), BitSet([3, 4])])) == true

    #     # Test 2: Test that is_valid_partition returns false for an invalid partition
    #     @test is_valid_partition(Set([BitSet([1, 2]), BitSet([2, 3])])) == false

    #     # Test 3: Test that is_valid_partition returns false for an invalid partition
    #     @test is_valid_partition(Set([BitSet([1, 2]), BitSet([2, 3]), BitSet([3, 4])])) ==
    #           false

    #     # Test 4: Test that is_valid_partition returns false for an invalid partition
    #     @test is_valid_partition(Set([BitSet([1, 2]), BitSet([4, 5])])) == false
    # end

    # @testset "materialize_constraints!(::Model)" begin
    #     import GraphPPL:
    #         materialize_constraints!,
    #         EdgeLabel,
    #         node_options,
    #         EdgeLabel,
    #         factorization_constraint,
    #         get_constraint_names

    #     # Test 1: Test materialize with a Mean Field constraint
    #     model = create_terminated_model(simple_model)
    #     ctx = GraphPPL.getcontext(model)
    #     materialize_constraints!(model)
    #     node = first(GraphPPL.neighbors(model, ctx[:z]))
    #     @test get_constraint_names(factorization_constraint(model[node])) ==
    #           ((:out, :μ, :σ),)

    # end

    # @testset "materialize_constraints!(:Model, ::NodeLabel, ::FactorNodeData)" begin
    #     import GraphPPL:
    #         materialize_constraints!, EdgeLabel, node_options, apply!, get_constraint_names

    #     # Test 1: Test materialize with a Full Factorization constraint
    #     model = create_terminated_model(simple_model)
    #     ctx = GraphPPL.getcontext(model)
    #     node = first(neighbors(model, ctx[:z]))
    #     materialize_constraints!(model, node)
    #     @test get_constraint_names(factorization_constraint(model[node])) ==
    #           ((:out, :μ, :σ),)

    #     # Test 2: Test materialize with a MeanField Factorization constraint
    #     model = create_terminated_model(simple_model)
    #     ctx = GraphPPL.getcontext(model)
    #     node = first(neighbors(model, ctx[:z]))

    #     constraint = FactorizationConstraint(
    #         (
    #             IndexedVariable(:x, nothing),
    #             IndexedVariable(:y, nothing),
    #             IndexedVariable(:z, nothing),
    #         ),
    #         MeanField(),
    #     )
    #     apply!(model, ctx, constraint)
    #     materialize_constraints!(model, node)
    #     @test get_constraint_names(factorization_constraint(model[node])) ==
    #           ((:out,), (:μ,), (:σ,))
    # end

    @testset "Resolved Constraints in" begin
        import GraphPPL:
            ResolvedFactorizationConstraint,
            ResolvedFactorizationConstraintLHS,
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

    @testset "ResolvedFactorizationConstraint" begin
        import GraphPPL:
            ResolvedFactorizationConstraint,
            ResolvedFactorizationConstraintLHS,
            ResolvedFactorizationConstraintEntry,
            ResolvedIndexedVariable,
            SplittedRange,
            apply!
        __model__ = create_terminated_model(outer)
        __context__ = GraphPPL.getcontext(__model__)
        __inner_context__ = __context__[inner, 1]
        __inner_inner_context__ = __inner_context__[inner_inner, 1]

        __normal_node__ = __inner_inner_context__[NormalMeanVariance, 1]
        let constraint = ResolvedFactorizationConstraint(
                ResolvedFactorizationConstraintLHS((
                    ResolvedIndexedVariable(:w, 2:3, __context__),
                )),
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
                ResolvedFactorizationConstraintLHS((
                    ResolvedIndexedVariable(:w, 4:5, __context__),
                )),
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
                ResolvedFactorizationConstraintLHS((
                    ResolvedIndexedVariable(:w, 2:3, __context__),
                )),
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
                ResolvedFactorizationConstraintLHS((
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
                ResolvedFactorizationConstraintLHS((
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
    end
end

end
