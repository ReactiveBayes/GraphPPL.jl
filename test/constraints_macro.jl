module test_constraints_macro

using Test
using TestSetExtensions
using GraphPPL
using MacroTools



function create_simple_model()
    model = GraphPPL.create_model()
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
    return model
end

macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end

@testset ExtendedTestSet "constraints_macro" begin

    @testset "FactorizationConstraint" begin
        import GraphPPL: FactorizationConstraint

        # Test 1: Test FactorizationConstraint constructor
        fc = FactorizationConstraint((:x, :y), ((:x, ), (:y, )))
        @test fc.variables == (:x, :y)
        @test fc.factorization == ((:x, ), (:y, ))

        # Test 2: Test FactorizationConstraint constructor with three variables
        fc = FactorizationConstraint((:x, :y, :z), ((:x, :y), (:z, )))
        @test fc.variables == (:x, :y, :z)
        @test fc.factorization == ((:x, :y), (:z, ))

        # Test 3: Test FactorizationConstraint constructor with one variable
        fc = FactorizationConstraint((:x,), ((:x,),))
        @test fc.variables == (:x,)
        @test fc.factorization == ((:x,),)

        # Test 4: Test FactorizationConstraint constructor with empty variables and factorization
        fc = FactorizationConstraint((), ())
        @test fc.variables == ()
        @test fc.factorization == ()
    
        # Test 5: Test FactorizationConstraint constructor with non-tuple elements
        @test_throws MethodError FactorizationConstraint(:x, (:x, ))

    end

    @testset "FunctionalFormConstraint" begin
        import GraphPPL: FunctionalFormConstraint
    
        # Test 1: Test FunctionalFormConstraint constructor with two variables
        fc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        @test fc.variable == :x
        @test_expression_generating fc.expression Expr(:call, :PointMass)
    end


    # Test GeneralSubModelConstraints struct
    @testset "GeneralSubModelConstraints" begin
        import GraphPPL: GeneralSubModelConstraints, FactorizationConstraint, Constraints, SubModelConstraints

        function fform end
        # Test constructor
        c = Constraints([FactorizationConstraint((:x, :y), ((:x, ), (:y, )))], [], [])
        @test GeneralSubModelConstraints(fform, c) == GeneralSubModelConstraints(fform, c)
        
        # Test fform field
        @test GeneralSubModelConstraints(fform, c).fform == fform
        
        # Test constraints field
        @test GeneralSubModelConstraints(fform, c).constraints == c
    end

     # Test GeneralSubModelConstraints struct
     @testset "SpecificSubModelConstraints" begin
        import GraphPPL: SpecificSubModelConstraints, FactorizationConstraint, Constraints, SubModelConstraints

        # Test constructor
        c = Constraints([FactorizationConstraint((:x, :y), ((:x, ), (:y, )))], [], [])
        @test SpecificSubModelConstraints(:fform_3, c) == SpecificSubModelConstraints(:fform_3, c)
        
        # Test fform field
        @test SpecificSubModelConstraints(:fform_3, c).tag == :fform_3
        
        # Test constraints field
        @test SpecificSubModelConstraints(:fform_3, c).constraints == c
    end


        # Test Constraints struct
    @testset "Constraints" begin
        import GraphPPL: Constraints, FactorizationConstraint, FunctionalFormConstraint, all_constraints, SubModelConstraints

        # Test constructor
        fc = FactorizationConstraint((:x, :y), ((:x, ), (:y, )))
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        c = Constraints([fc], [ffc], [])
        @test c.factorization_constraints == [fc]
        @test c.functional_form_constraints == [ffc]
        @test c.submodel_constraints == []
        
        # Test constraints function
        @test all_constraints(c) == [fc, ffc]

        # Test Constraints constructor with submodel_constraints
        c = Constraints([fc], [ffc], [SubModelConstraints(:fform_3, Constraints([fc], [ffc], []))])
        @test c.factorization_constraints == [fc]
        @test c.functional_form_constraints == [ffc]
        sm_c = c.submodel_constraints[1]
        @test sm_c.tag == :fform_3
        @test sm_c.constraints.factorization_constraints == [fc]
        @test sm_c.constraints.functional_form_constraints == [ffc]
    end

    @testset "SubModelConstraints" begin
        import GraphPPL: SubModelConstraints, FactorizationConstraint, Constraints, SpecificSubModelConstraints, GeneralSubModelConstraints
        function fform end
        c = Constraints([FactorizationConstraint((:x, :y), ((:x, ), (:y, )))], [], [])

        # Test SubModelConstraints constructor with symbol
        @test SubModelConstraints(:fform_3, c) == SpecificSubModelConstraints(:fform_3, c)

        # Test SubModelConstraints constructor with function
        @test SubModelConstraints(fform, c) == GeneralSubModelConstraints(fform, c)

    end
    
    @testset "apply!(::Model, ::Constraints)" begin
        import GraphPPL: apply!
        model = create_simple_model()
        
        # Test 1: Test apply! with simple constraints
        c = Constraints([FactorizationConstraint((:x, :y, :out), ((:x, :y), (:out, )))], [], [])
        apply!(model, c)
    end

    @testset "apply!(::Model, ::Context, ::FactorizationConstraint)" begin
        import GraphPPL: apply!, node_options, create_model
        model = create_simple_model()
        ctx = GraphPPL.context(model)

        # Test 1: Test apply! with simple constraints
        fc = FactorizationConstraint((:x, :y, :out), ((:x, :y), (:out, )))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:constraint] == ((GraphPPL.EdgeLabel(:in, 1), GraphPPL.EdgeLabel(:in, 2)), (GraphPPL.EdgeLabel(:out, nothing),))

        # Test 2: Apply new factorization constraint to same node
        fc = FactorizationConstraint((:x, :y, :out), ((:x, ), (:y, :out)))
        @test_throws ErrorException apply!(model, ctx, fc)

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
        fc = FactorizationConstraint((:x, :y, :out), ((:x, ), (:y, :out)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:constraint] == ((GraphPPL.EdgeLabel(:in, 1),), (GraphPPL.EdgeLabel(:in, 2), GraphPPL.EdgeLabel(:out, nothing),))
        @test node_options(model[ctx[:sum_5]])[:constraint] == ((GraphPPL.EdgeLabel(:in, 1),), (GraphPPL.EdgeLabel(:in, 2), GraphPPL.EdgeLabel(:out, nothing),))

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
            __parent_options__ = Dict{Any, Any}(:q => :(q(out, x, y))),
        )
        fc = FactorizationConstraint((:x, :y, :out), ((:x, ), (:y, :out)))
        apply!(model, ctx, fc)
        @test node_options(model[ctx[:sum_4]])[:constraint] == ((GraphPPL.EdgeLabel(:in, 1),), (GraphPPL.EdgeLabel(:in, 2), GraphPPL.EdgeLabel(:out, nothing),))

        # Test 5: Apply factorization constraint to node in vector
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        GraphPPL.make_node!(
            model,
            ctx,
            +,
            out,
            [x[1], y];
            __debug__ = false,
            __parent_options__ = Dict{Any, Any}(:q => :(q(out, x, y))),
        )
        fc = FactorizationConstraint((:x, :y, :out), ((:x, ), (:y, :out)))
        @test_throws MethodError apply!(model, ctx, fc)
        @test_broken node_options(model[ctx[:sum_4]])[:constraint] == ((GraphPPL.EdgeLabel(:in, 1),), (GraphPPL.EdgeLabel(:in, 2), GraphPPL.EdgeLabel(:out, nothing),))

        # Test 6: Apply factorization to node that does not exist
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        fc = FactorizationConstraint((:x, :y, :out), ((:x, ), (:y, :out)))
        @test_warn "" apply!(model, ctx, fc)
    end

    @testset "apply!(::Model, ::Context, ::FunctionalFormConstraint)" begin
        import GraphPPL: apply!, node_options, create_model

        # Test 1: Test apply! with simple constraints
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        apply!(model, ctx, ffc)
        @test node_options(model[ctx[:x]])[:constraint] == Expr(:call, :PointMass)

        # Test 2: Test that apply! with non-existant constraints throws error
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        ffc = FunctionalFormConstraint(:test, Expr(:call, :PointMass))
        @test_throws ErrorException apply!(model, ctx, ffc)
    end

    @testset "store_constraint!(::Model, ::NodeLabel, ::FactorizationConstraint)" begin
        import GraphPPL: store_constraint!, node_options, create_model, EdgeLabel
        # Test saving factorization constraint
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
            __parent_options__ = nothing,
        )
        node = ctx[:sum_4]
        fc = FactorizationConstraint((:x, :y), ((:x, ), (:y, ), (:out,)))
        store_constraint!(model, ctx, node, fc)
        @test node_options(model[node])[:constraint] == ((EdgeLabel(:in, 1),), (EdgeLabel(:in, 2),), (EdgeLabel(:out, nothing),))

        # Test saving functional form constraint
        ffc = FunctionalFormConstraint(:x, Expr(:call, :PointMass))
        store_constraint!(model, ctx, x, ffc)
        @test node_options(model[x])[:constraint] == Expr(:call, :PointMass)
    end

    @testset "get_interface_names" begin
        import GraphPPL: get_interface_names, EdgeLabel
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        node = ctx[:sum_4]
        @test get_interface_names(model, ctx, node, ((:x, ), (:y, ), (:out,))) == ((EdgeLabel(:in, 1),), (EdgeLabel(:in, 2),), (EdgeLabel(:out, nothing),))
        @test get_interface_names(model, ctx, node, ((:x, :y), (:out,))) == ((EdgeLabel(:in, 1), EdgeLabel(:in, 2)), (EdgeLabel(:out, nothing),))
    
    end

    @testset "contains_array_variable" begin
        import GraphPPL: contains_array_variable

        # Test 1: Test that contains_array_variable returns false for non-array variables
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test contains_array_variable(ctx, (:x, :y, :out)) == Val(false)      

        # Test 2: Test that contains_array_variable returns true for array variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        @test contains_array_variable(ctx, (:x, :y, :out)) == Val(true)

        # Test 3: Test that contains_array_variable returns true for array variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, 1)
        out = GraphPPL.getorcreate!(model, ctx, :out, 1)
        @test contains_array_variable(ctx, (:x, :y, :out)) == Val(true)

        # Test 4: Test that contains_array_variable returns true for tensor variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, 1, 1)
        out = GraphPPL.getorcreate!(model, ctx, :out, 1, 1)
        @test contains_array_variable(ctx, (:x, :y, :out)) == Val(true)
    end

    @testset "references_existing_variables" begin
        import GraphPPL: references_existing_variables

        # Test 1: Test that references_existing_variables returns true for existing
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test references_existing_variables(ctx, (:x, :y, :out)) == Val(true)

        # Test 2: Test that references_existing_variables returns false for non-existing
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test references_existing_variables(ctx, (:x, :y, :out, :test)) == Val(false)

        # Test 3: Test that references_existing_variables returns true for existing array variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        out = GraphPPL.getorcreate!(model, ctx, :out, nothing)
        @test references_existing_variables(ctx, (:x, :y, :out)) == Val(true)

        # Test 4: Test that references_existing_variables returns true for existing tensor variables
        model = create_model()
        ctx = GraphPPL.context(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1, 1)
        y = GraphPPL.getorcreate!(model, ctx, :y, 1, 1)
        out = GraphPPL.getorcreate!(model, ctx, :out, 1, 1)
        @test references_existing_variables(ctx, (:x, :y, :out)) == Val(true)

        # Test 5: Test that references_existing_variables returns false for factor nodes
        model = create_simple_model()
        ctx = GraphPPL.context(model)
        @test references_existing_variables(ctx, (:x, :y, :sum_4)) == Val(false)


    end
end

end
