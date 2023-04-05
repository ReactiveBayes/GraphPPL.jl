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
        @test missing_interfaces(sum, Val(3), Dict()) == [:in1, :in2, :out]

        GraphPPL.interfaces(::typeof(prod), ::Val{0}) = []
        @test missing_interfaces(prod, Val(0), (in1 = :x, in2 = :y)) == []

        GraphPPL.interfaces(::typeof(sin), ::Val{2}) = (:a, :b)
        @test missing_interfaces(sin, Val(2), (a = 1, b = 2)) == []

        GraphPPL.interfaces(::typeof(div), ::Val{2}) = (:in1, :in2, :out)
        @test missing_interfaces(div, Val(2), (in1 = 1, in2 = 2, out = 3, test = 4)) == []
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

    @testset "generate_get_or_create_expression(::Expr)" begin
        import GraphPPL: generate_get_or_create_expression
        input = Expr(:tuple, [:x, :y])
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
        end
        @test_expression_generating(generate_get_or_create_expression(input), output)

        input = Expr(:tuple, [:x, 1])
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

    @testset "is_kwargs_expression(::AbstractArray)" begin
        import GraphPPL: is_kwargs_expression

        func_def = :(foo(a, b))
        @capture(func_def, (f_(args__)))
        @test !is_kwargs_expression(args)

        func_def = :(foo(a = a, b = b))
        @capture(func_def, (f_(args__)))
        @test is_kwargs_expression(args)

        empty_args = Expr(:tuple)
        @test !is_kwargs_expression(empty_args)

        empty_args = :(foo())
        @capture(empty_args, (f_(args__)))
        @test !is_kwargs_expression(args)

        mixed_args = :(foo(a, b, c = c))
        @capture(mixed_args, (f_(args__)))
        @test !is_kwargs_expression(args)

        nested_args = :(foo(a = a, b = b, c = (d = d)))
        @capture(nested_args, (f_(args__)))
        @test is_kwargs_expression(args)
    end

    @testset "keyword_expressions_to_named_tuple" begin
        import GraphPPL: keyword_expressions_to_named_tuple

        expr = [:($(Expr(:kw, :in1, :y))), :($(Expr(:kw, :in2, :z)))]
        @test keyword_expressions_to_named_tuple(expr) == (; zip((:in1, :in2), (:y, :z))...)
    end

    @testset "generate_make_node_call(::Any, NamedTuple)" begin
        import GraphPPL: create_model, generate_make_node_call

        #test default functionality
        input = (sum, (in = :x, out = :y))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            interfaces_tuple = (in = x, out = y)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end

        @test_expression_generating(generate_make_node_call(input...), output)

        #test expression functionality
        input = (sum, (in = :([x]), out = :y))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            interfaces_tuple = (in = [x], out = y)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end

        @test_expression_generating(generate_make_node_call(input...), output)

        #test vector functionality
        input = (sum, (in = :([x, z]), out = :y))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            z = (@isdefined(z)) ? z : GraphPPL.getorcreate!(model, context, :z)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            interfaces_tuple = (in = [x, z], out = y)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end

        @test_expression_generating(generate_make_node_call(input...), output)

        #Test empty interfaces
        input = (sum, NamedTuple())
        output = quote
            interfaces_tuple = ()
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end
        @test_expression_generating(generate_make_node_call(input...), output)

        #test illegal interfaces
        input = (sum, (in = :x, out = :(1 + 2)))
        @test_throws MethodError generate_make_node_call(input...)

        #test with nested interfaces
        input = (sum, (inputs = (in1 = :x, in2 = :y), output = :z))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            z = (@isdefined(z)) ? z : GraphPPL.getorcreate!(model, context, :z)
            interfaces_tuple = (inputs = (in1 = x, in2 = y), output = z)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end
        @test_expression_generating(generate_make_node_call(input...), output)


        interfaces = (in1 = :x, in2 = :y, in3 = :test, in4 = :a)
        input = (sum, (inputs = interfaces, output = :z))
        output = quote
            x = (@isdefined(x)) ? x : GraphPPL.getorcreate!(model, context, :x)
            y = (@isdefined(y)) ? y : GraphPPL.getorcreate!(model, context, :y)
            test =
                (@isdefined(test)) ? test : GraphPPL.getorcreate!(model, context, :test)
            a = (@isdefined(a)) ? a : GraphPPL.getorcreate!(model, context, :a)
            z = (@isdefined(z)) ? z : GraphPPL.getorcreate!(model, context, :z)
            interfaces_tuple =
                (inputs = (in1 = x, in2 = y, in3 = test, in4 = a), output = z)
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end
        @test_expression_generating(generate_make_node_call(input...), output)
    end

    @testset "extract_interfaces(::AbstractArray, ::Expr)" begin
        import GraphPPL: extract_interfaces

        interfaces = [:x, :y]
        ms_body = quote
            some
            unimportant
            lines
            return z
        end
        @test extract_interfaces(interfaces, ms_body) == [:x, :y, :z]

        interfaces = [:x, :y]
        ms_body = quote
            some
            unimportant
            lines
            return
        end
        @test extract_interfaces(interfaces, ms_body) == [:x, :y]

        interfaces = [:x, :y]
        ms_body = quote
            some
            unimportant
            lines
            return z, a, b, c
        end
        @test extract_interfaces(interfaces, ms_body) == [:x, :y, :z, :a, :b, :c]


    end

end

end
