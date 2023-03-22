module test_model_macro

using Test
using GraphPPL
using Graphs
using TestSetExtensions
using MacroTools

@testset "model_macro" begin

    @testset "missing_interfaces" begin
        import GraphPPL: missing_interfaces, interfaces
        GraphPPL.interfaces(::typeof(sum), ::Val{3}) = (:in1, :in2, :out)

        @test missing_interfaces(sum, Val(3), (in1 = :x, in2 = :y)) == [:out]
        @test missing_interfaces(sum, Val(3), (out = :y,)) == [:in1, :in2]
    end

    @testset "generate_get_or_create_expression(::AbstractArray)" begin
        import GraphPPL: generate_get_or_create_expression
        input = [:x, :y]
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
        end
        @test_expression_generating(generate_get_or_create_expression(input), output)

        input = [:x, 1]
        @test_throws MethodError GraphPPL.generate_get_or_create_expression(input)
    end

    @testset "generate_get_or_create_expression(::Symbol)" begin
        input = :x
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
        end
        @test_expression_generating(generate_get_or_create_expression(input), output)

        input = 1
        @test_throws MethodError GraphPPL.generate_get_or_create_expression(input)
    end

    @testset "keyword_expressions_to_named_tuple" begin
        import GraphPPL: keyword_expressions_to_named_tuple

        expr = [:($(Expr(:kw, :in1, :y))), :($(Expr(:kw, :in2, :z)))]
        @test keyword_expressions_to_named_tuple(expr) == (; zip((:in1, :in2), (:y, :z))...)
    end

    @testset "generate_make_node_call(::Any, NamedTuple)" begin
        import GraphPPL: create_model, generate_make_node_call

        input = (sum, (in = :x, out = :y))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            interfaces_tuple = (in = x, out = y)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end

        @test_expression_generating(generate_make_node_call(input...), output)

        input = (sum, (in = :([x]), out = :y))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            interfaces_tuple = (in = [x], out = y)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end

        @test_expression_generating(generate_make_node_call(input...), output)

        input = (sum, (in = :([x, z]), out = :y))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            z = (@isdefined(z)) ? z : GraphPPL.getorcreate!(model, context, :z)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            interfaces_tuple = (in = [x, z], out = y)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end

        @test_expression_generating(generate_make_node_call(input...), output)


    end

end

end
