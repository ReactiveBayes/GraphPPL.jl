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
    GraphPPL.make_node!(model, ctx, +, out, [x, y]; __debug__=false, __parent_options__=nothing)
    return model
end

macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end

@testset ExtendedTestSet "constraints_macro" begin
    @testset "Constraints" begin
        import GraphPPL: Constraints

        # Test 1: Test Constraints constructor with variable constraints
        c = Constraints(Dict(:x => :(q(x, y) = q(x)q(y)), :y => :(q(x, y) = q(x)q(y))))
        @test_expression_generating c.variable_constraints[:x] :(q(x, y) = q(x)q(y))
        @test_expression_generating c.variable_constraints[:y] :(q(x, y) = q(x)q(y))
    end

    @testset "apply_to_variable_nodes" begin
        import GraphPPL: apply!, node_options

        # Test 1: Test apply! with only variable nodes
        c = Constraints(Dict(:x => :(q(x, y) = q(x)q(y)), :y => :(q(x, y) = q(x)q(y))))
        model = create_simple_model()
        apply!(model, c)
        @test_expression_generating node_options(model[GraphPPL.context(model)[:x]])[:constraints][1] :(q(x, y) = q(x)q(y))
        @test_expression_generating node_options(model[GraphPPL.context(model)[:y]])[:constraints][1] :(q(x, y) = q(x)q(y))
        @test node_options(model[GraphPPL.context(model)[:out]]) === nothing

        # Test 2: Test apply! with variable nodes when nodes already have constraints
        c = Constraints(Dict(:x => :(q(x, y) = q(x, y)), :y => :(q(x, y) = q(x, y))))
        apply!(model, c)
        @test_expression_generating node_options(model[GraphPPL.context(model)[:x]])[:constraints][1] :(q(x, y) = q(x)q(y))
        @test_expression_generating node_options(model[GraphPPL.context(model)[:x]])[:constraints][2] :(q(x, y) = q(x, y))
        @test_expression_generating node_options(model[GraphPPL.context(model)[:y]])[:constraints][1] :(q(x, y) = q(x)q(y))
        @test_expression_generating node_options(model[GraphPPL.context(model)[:y]])[:constraints][2] :(q(x, y) = q(x, y))
        @test node_options(model[GraphPPL.context(model)[:out]]) === nothing
    end
end

end