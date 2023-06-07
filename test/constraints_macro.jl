module test_constraints_macro

using Test
using TestSetExtensions
using GraphPPL
using MacroTools
include("model_zoo.jl")

@testset ExtendedTestSet "constraints_macro" begin

    @testset "FactorizationConstraint" begin
        import GraphPPL: FactorizationConstraint

        # Test 1: Test FactorizationConstraint constructor
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        @test fc.variables == (:x, :y)
        @test fc.constraint == ((:x,), (:y,))

        # Test 2: Test FactorizationConstraint constructor with three variables
        fc = FactorizationConstraint((:x, :y, :z), ((:x, :y), (:z,)))
        @test fc.variables == (:x, :y, :z)
        @test fc.constraint == ((:x, :y), (:z,))

        # Test 3: Test FactorizationConstraint constructor with one variable
        fc = FactorizationConstraint((:x,), ((:x,),))
        @test fc.variables == (:x,)
        @test fc.constraint == ((:x,),)

        # Test 4: Test FactorizationConstraint constructor with empty variables and factorization
        fc = FactorizationConstraint((), ())
        @test fc.variables == ()
        @test fc.constraint == ()

        # Test 5: Test FactorizationConstraint constructor with MeanField constructor
        fc = FactorizationConstraint((:x, :y), MeanField())

    end

    @testset "FunctionalFormConstraint" begin
        import GraphPPL: FunctionalFormConstraint, IndexedVariable

        # Test 1: Test FunctionalFormConstraint constructor with two variables
        fc = FunctionalFormConstraint(:x, PointMass())
        @test fc.variables == :x
        @test fc.constraint == PointMass()

        # Test 2: Test FunctionalFormConstraint constructor with IndexedVariable
        fc = FunctionalFormConstraint(IndexedVariable(:x, [1]), PointMass())
        @test fc.variables.variable == :x && fc.variables.index == [1]
    end


    # Test GeneralSubModelConstraints struct
    @testset "GeneralSubModelConstraints" begin
        import GraphPPL:
            GeneralSubModelConstraints,
            FactorizationConstraint,
            Constraints,
            SubModelConstraints

        function fform end
        # Test constructor
        c = Constraints([FactorizationConstraint((:x, :y), ((:x,), (:y,)))])
        @test GeneralSubModelConstraints(fform, c) == GeneralSubModelConstraints(fform, c)

        # Test fform field
        @test GeneralSubModelConstraints(fform, c).fform == fform

        # Test constraints field
        @test GeneralSubModelConstraints(fform, c).constraints == c
    end

    # Test GeneralSubModelConstraints struct
    @testset "SpecificSubModelConstraints" begin
        import GraphPPL:
            SpecificSubModelConstraints,
            FactorizationConstraint,
            Constraints,
            SubModelConstraints

        # Test constructor
        c = Constraints([FactorizationConstraint((:x, :y), ((:x,), (:y,)))])
        @test SpecificSubModelConstraints(:fform_3, c) ==
              SpecificSubModelConstraints(:fform_3, c)

        # Test fform field
        @test SpecificSubModelConstraints(:fform_3, c).tag == :fform_3

        # Test constraints field
        @test SpecificSubModelConstraints(:fform_3, c).constraints == c
    end


    # Test Constraints struct
    @testset "Constraints" begin
        import GraphPPL:
            Constraints,
            FactorizationConstraint,
            FunctionalFormConstraint,
            SubModelConstraints,
            Constraint

        # Test constructor
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        c = Constraints([fc, ffc])
        @test c == [fc, ffc]

        # Test Constraints constructor with submodel_constraints
        smc = SubModelConstraints(:fform_3, Constraints([fc, ffc]))
        c = Constraints([fc, ffc, smc],)
        @test c == Constraint[fc, ffc, smc]

    end

    @testset "SubModelConstraints" begin
        import GraphPPL:
            SubModelConstraints,
            FactorizationConstraint,
            Constraints,
            SpecificSubModelConstraints,
            GeneralSubModelConstraints,
            Constraint
        function fform end
        c = Constraints([FactorizationConstraint((:x, :y), ((:x,), (:y,)))])

        # Test SubModelConstraints constructor with symbol
        @test SubModelConstraints(:fform_3, c) == SpecificSubModelConstraints(:fform_3, c)

        # Test SubModelConstraints constructor with function
        @test SubModelConstraints(fform, c) == GeneralSubModelConstraints(fform, c)

    end

    # @testset "apply!(::Model, ::Constraints)" begin
    #     import GraphPPL: apply!
    #     model = create_simple_model()

    #     # Test 1: Test apply! with simple constraints
    #     c = Constraints(
    #         [FactorizationConstraint((:x, :y, :out), ((:x, :y), (:out,)))],
    #     )
    #     apply!(model, c)
    # end

    # @testset "apply!(::Model, ::GeneralSubModelConstraints)" begin
    #     import GraphPPL: apply!, node_options, create_model, node_options, materialize_constraints!, EdgeLabel

    #     # Test 1: Test apply! with simple constraints
    #     model = create_nested_model()
    #     ctx = GraphPPL.context(model)
    #     constraints = SubModelConstraints(submodel_with_deterministic_functions_and_anonymous_variables, Constraints([FactorizationConstraint((:z, :w), ((:z,) , (:w,))), FunctionalFormConstraint(:w, Expr(:call, :PointMass))]))
    #     apply!(model, ctx, constraints)
    #     materialize_constraints!(model)
    #     @test node_options(model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:exp_15]])[:q] == ((EdgeLabel(:out, nothing), ), (EdgeLabel(:in, 1), ), )
    #     @test node_options(model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_4][:exp_9]])[:q] == ((EdgeLabel(:out, nothing), ), (EdgeLabel(:in, 1), ), )
    #     @test node_options(model[ctx[:second_submodel_16][:exp_22]])[:q] == ((EdgeLabel(:in, 1), EdgeLabel(:out, nothing)),)
    #     @test node_options(model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:w]])[:q] == Expr(:call, :PointMass)

    #     # Test 2: Test apply! with constraints that reference constants as well
    #     model = create_nested_model()
    #     ctx = GraphPPL.context(model)
    #     constraints = SubModelConstraints(second_submodel, Constraints([FactorizationConstraint((:c,:w), ((:c,), (:w,)))], [], []))
    #     apply!(model, ctx, constraints)
    #     @test_broken materialize_constraints!(model)
    # end

    # @testset "apply!(::Model, ::SpecificSubModelConstraints)" begin
    #     import GraphPPL: apply!

    #     # Test 1: Test apply! with simple constraints
    #     model = create_nested_model()
    #     ctx = GraphPPL.context(model)
    #     constraints = SubModelConstraints(:submodel_with_deterministic_functions_and_anonymous_variables_10, Constraints([FactorizationConstraint((:z, :w), ((:z,) , (:w,)))], [FunctionalFormConstraint(:w, Expr(:call, :PointMass))], []))
    #     apply!(model, ctx, constraints)
    #     materialize_constraints!(model)
    #     @test node_options(model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_10][:exp_15]])[:q] == ((EdgeLabel(:out, nothing), ), (EdgeLabel(:in, 1), ), )
    #     @test node_options(model[ctx[:submodel_with_deterministic_functions_and_anonymous_variables_4][:exp_9]])[:q] == ((EdgeLabel(:out, nothing),  EdgeLabel(:in, 1), ),)
    # end

    @testset "apply!(::Model, ::Context, ::FactorizationConstraint)" begin
        import GraphPPL: apply!, node_options, create_model
        model = create_simple_model()
        ctx = GraphPPL.context(model)

        # Test 1: Test apply! with simple constraints
        fc = FactorizationConstraint((:x, :y, :out), ((:x, :y), (:out,)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1, 2]), BitSet([1, 2]), BitSet([3])]

        # Test 2: Apply new factorization constraint to same node
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1]), BitSet([2]), BitSet([3])]

        # Test 3: Apply factorization constraint to two nodes
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        GraphPPL.make_node!(
            model,
            ctx,
            +,
            out,
            [x, y];
            __debug__ = false,
            __parent_options__ = nothing,
        )
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]
        @test node_options(model[ctx[:sum_5]])[:q] ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]

        # Test 4: Apply factorization constraint to node that already has options defined
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        GraphPPL.make_node!(
            model,
            ctx,
            +,
            out,
            [x, y];
            __debug__ = false,
            __parent_options__ = Dict{Any,Any}(:q => :(q(out, x, y))),
        )
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]

        # Test 5: Apply factorization constraint to node in vector
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_12]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]

        # Test 6: Apply factorization constraint to vector of nodes that applies to mulitple nodes
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]
        @test node_options(model[ctx[:sum_7]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]
        @test node_options(model[ctx[:sum_10]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]
        @test node_options(model[ctx[:sum_12]])[:q] ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 7: Apply factorization constraint to tensor of nodes that applies to mulitple nodes
        model = create_tensor_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]
        @test node_options(model[ctx[:sum_7]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]
        @test node_options(model[ctx[:sum_10]])[:q] ==
              [BitSet([1, 3]), BitSet([2]), BitSet([1, 3])]
        @test node_options(model[ctx[:sum_12]])[:q] ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 8: Apply factorization to node that does not exist
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        @test_logs (:warn, "No applicable nodes found for constraint $fc") apply!(
            model,
            ctx,
            fc,
        )

        # Test 9: Apply factorization to node with indexed statement
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint(
            (:x,),
            ((IndexedVariable(:x, [1]),), (IndexedVariable(:x, [2]),)),
        )
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1, 2]), BitSet([1, 2, 3]), BitSet([2, 3])]

        # Test 10: Apply factorization to node with indexed statement with a joint
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint(
            (:x,),
            (
                (IndexedVariable(:x, [1]), IndexedVariable(:x, [2])),
                (IndexedVariable(:x, [3]),),
            ),
        )
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]
        @test node_options(model[ctx[:sum_7]])[:q] ==
              [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]

        # Test 11: Apply factorization constraint with duplicate entries
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x), (IndexedVariable(:x, [1]), IndexedVariable(:x, [1])))


    end

    # @testset "apply!(::Model, ::Context, ::FunctionalFormConstraint)" begin
    #     import GraphPPL: apply!, node_options, create_model, IndexedVariable

    #     # Test 1: Test apply! with simple constraints
    #     model = create_simple_model()
    #     ctx = GraphPPL.context(model)
    #     ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
    #     apply!(model, ctx, ffc)
    #     @test node_options(model[ctx[:x]])[:q] == Expr(:call, :PointMass)

    #     # Test 2: Test that apply! with non-existant constraints throws error
    #     model = create_simple_model()
    #     ctx = GraphPPL.context(model)
    #     ffc = FunctionalFormConstraint(:test, Expr(:call, :PointMass))
    #     @test_throws ErrorException apply!(model, ctx, ffc)

    #     # Test 3: Apply functional form constraint to vector of nodes
    #     model = create_vector_model()
    #     ctx = GraphPPL.context(model)
    #     ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
    #     apply!(model, ctx, ffc)
    #     @test node_options(model[ctx[:x][1]])[:q] == Expr(:call, :PointMass)
    #     @test node_options(model[ctx[:x][2]])[:q] == Expr(:call, :PointMass)
    #     @test node_options(model[ctx[:x][3]])[:q] == Expr(:call, :PointMass)

    #     # Test 4: Apply functional form constraint to tensor of nodes
    #     model = create_tensor_model()
    #     ctx = GraphPPL.context(model)
    #     ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
    #     apply!(model, ctx, ffc)
    #     @test node_options(model[ctx[:x][1, 1]])[:q] == Expr(:call, :PointMass)
    #     @test node_options(model[ctx[:x][2, 2]])[:q] == Expr(:call, :PointMass)
    #     @test node_options(model[ctx[:x][3, 3]])[:q] == Expr(:call, :PointMass)

    #     # Test 5: Apply functional form constraint to single node in vector

    #     model = create_vector_model()
    #     ctx = GraphPPL.context(model)
    #     ffc = FunctionalFormConstraint(IndexedVariable(:x, [1]), Expr(:call, :PointMass))
    #     apply!(model, ctx, ffc)
    #     @test node_options(model[ctx[:x][1]])[:q] == Expr(:call, :PointMass)
    #     @test node_options(model[ctx[:x][2]]) === nothing

    # end



    @testset "throw_var_not_defined" begin
        import GraphPPL: throw_var_not_defined, create_model

        # Test 1: Test that throw_var_not_defined returns true for existing
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test throw_var_not_defined(ctx, (:x, :y, :out)) isa Any

        # Test 2: Test that throw_var_not_defined returns false for non-existing
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test_throws ErrorException throw_var_not_defined(ctx, (:x, :y, :out, :test))

        # Test 3: Test that throw_var_not_defined returns true for existing array variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        @test throw_var_not_defined(ctx, (:x, :y, :out)) isa Any

        # Test 4: Test that throw_var_not_defined returns true for existing tensor variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, 1, 1)
        out = GraphPPL.getorcreate!(model, ctx, :out, 1, 1)
        @test throw_var_not_defined(ctx, (:x, :y, :out)) isa Any

        # Test 5: Test that throw_var_not_defined returns false for factor nodes
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test_throws ErrorException throw_var_not_defined(ctx, (:x, :y, :sum_4))

        # Test 6: Test that throw_var_not_defined returns true for IndexedVariables in array
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        @test throw_var_not_defined(ctx, (:x, :y, IndexedVariable(:x, [1]))) isa Any
    end

    @testset "find_applicable_nodes" begin
        import GraphPPL: find_applicable_nodes


        # Test 1: Test that find_applicable_nodes in the case of all single random variables returns the correct node
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, fc) == [ctx[:sum_4]]

        # Test 2: Test that find_applicable_nodes in the case of all array random variables returns the correct node
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, fc) ==
              [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 3: Test that find_applicable_nodes in the case of mixed random variables returns the correct node
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, fc) == [ctx[:sum_12]]

        # Test 4: Test that find_applicable_nodes finds the correct node in case of a fform constraint
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, ffc) == [ctx[:x]]

        # Test 5: Test that find_applicable_nodes returns a vector of nodes in case of multiple applicable nodes
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, ffc) == [ctx[:x]...]

        # Test 6: Test that find_applicable_nodes returns vector of nodes if we have tensor input
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        model = create_tensor_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, fc) ==
              [ctx[:sum_4], ctx[:sum_7], ctx[:sum_10], ctx[:sum_12]]

        # Test 7: Test that find_applicable_nodes returns vector of nodes if we have tensor input 
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        model = create_tensor_model()
        ctx = GraphPPL.context(model)
        @test find_applicable_nodes(model, ctx, ffc) == vec(ctx[:x])
    end

    @testset "_get_from_context" begin
        import GraphPPL: _get_from_context, IndexedVariable

        # Test 1: Test that _get_from_context returns a single variable node when called with a single variable
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test _get_from_context(ctx, :x) == ctx[:x]

        # Test 2: Test that _get_from_context returns a single variable node when called with an indexed statement
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        @test _get_from_context(ctx, IndexedVariable(:x, [1])) == ctx[:x][1]

        # Test 3: Test that _get_from_context returns a single variable node when called with an indexed statement
        model = create_tensor_model()
        ctx = GraphPPL.context(model)
        @test _get_from_context(ctx, IndexedVariable(:x, [1, 1])) == ctx[:x][1, 1]

    end

    @testset "apply!(::Model, ::Context, ::Node, ::FactorizationConstraint{V, ::Tuple})" begin
        import GraphPPL: apply!, FactorizationConstraint, create_model, node_options

        # Test 1: Test that apply! returns the correct node in the case of all single random variables
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x, :y, :out), ((:x,), (:y, :out)))
        apply!(model, ctx, ctx[:sum_4], fc)
        @test node_options(model[ctx[:sum_4]])[:q] ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]

        # Test 2: Test that apply! returns the correct node in the case of all array random variables
        model = create_vector_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x, :y), ((:x,), (:y,)))
        apply!(model, ctx, ctx[:sum_4], fc)
    end

    @testset "apply!(::Model, ::Context, ::Node, ::FactorizationConstraint{V, ::MeanField})" begin
        import GraphPPL: apply!, FactorizationConstraint, EdgeLabel

        # Test 1: Test that apply! returns the correct node in the case of all single random variables
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        fc = FactorizationConstraint((:x, :y, :out), MeanField())
        apply!(model, ctx, ctx[:sum_4], fc)
        @test node_options(model[ctx[:sum_4]])[:q] == ((EdgeLabel(:in, 1),) , (EdgeLabel(:in, 2),), (EdgeLabel(:out, nothing),))

    end

    @testset "apply!(::Model, ::Context, ::Node, ::FactorizationConstraint{V, ::FunctionalFormConstraint})" begin
         # Test 1: Test that apply! returns the correct node in the case of all single random variables
         model = create_simple_model()
         ctx = GraphPPL.context(model)
         fc = FactorizationConstraint((:x, :y, :out), FullFactorization())
         apply!(model, ctx, ctx[:sum_4], fc)
         @test node_options(model[ctx[:sum_4]])[:q] == ((EdgeLabel(:in, 1), EdgeLabel(:in, 2), EdgeLabel(:out, nothing),),)
    end

    @testset "factorization_constraint_to_bitset" begin
        import GraphPPL: factorization_constraint_to_bitset, NodeLabel

        # Test 1: Test that convert_factorization_constraint returns the correct factorization constraint
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = ((NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:out, 1)))
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]

        # Test 2: Test that convert_factorization_constraint returns the correct factorization constraint
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = ((NodeLabel(:x, 1),), (NodeLabel(:y, 1),))
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1, 3]), BitSet([2, 3]), BitSet([1, 2, 3])]

        # Test 3: Test that convert_factorization_constraint returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = ((NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)))
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1]), BitSet([2, 3, 4]), BitSet([2, 3, 4]), BitSet([2, 3, 4])]

        # Test 4: Test that convert_factorization_constraint returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = ((NodeLabel(:x, 1), NodeLabel(:y, 1)), (NodeLabel(:z, 1), NodeLabel(:out, 1)))
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1, 2]), BitSet([1, 2]), BitSet([3, 4]), BitSet([3, 4])]

        # Test 5: Test that convert_factorization_constraint returns the correct factorization constraint
        neighbors =
            [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:z, 1), NodeLabel(:out, 1)]
        fc = ((NodeLabel(:x, 1), NodeLabel(:y, 1)), (NodeLabel(:z, 1),))
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1, 2, 4]), BitSet([1, 2, 4]), BitSet([3, 4]), BitSet([1, 2, 3, 4])]

        # Test 6: Test that factorization_constraint_to_bitset returns the correct factorization constraint when we have indexed statements
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = ((NodeLabel(:x, 1),), (NodeLabel(:y, 1), NodeLabel(:out, 1)))
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1]), BitSet([2, 3]), BitSet([2, 3])]

        # Test 7: Test that factorization_constraint_to_bitset with empty inputs returns full joint
        neighbors = [NodeLabel(:x, 1), NodeLabel(:y, 1), NodeLabel(:out, 1)]
        fc = ([], [])
        @test factorization_constraint_to_bitset(neighbors, fc) ==
              [BitSet([1, 2, 3]), BitSet([1, 2, 3]), BitSet([1, 2, 3])]
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
end

end
