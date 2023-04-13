module test_model_macro

using Test
using GraphPPL
using Graphs
using TestSetExtensions
using MacroTools

@testset "model_macro" begin

    @testset "guarded_walk" begin
        import GraphPPL: guarded_walk

        #Test 1: walk with indexing operation as guard
        g_walk = guarded_walk((x) -> x isa Expr && x.head == :ref)

        input = quote
            x[i+1] + 1
        end

        output = quote
            sum(x[i+1], 1)
        end

        result = g_walk(input) do x
            if @capture(x, (a_ + b_))
                return :(sum($a, $b))
            else
                return x
            end
        end

        @test_expression_generating result output

        #Test 2: walk with complexer guard function
        custom_guard(x) = x isa Expr && (x.head == :ref || x.head == :call)

        g_walk = guarded_walk(custom_guard)

        input = quote
            x[i+1] * y[j-1] + z[k+2]()
        end

        output = quote
            sum(x[i+1] * y[j-1], z[k+2]())
        end

        result = g_walk(input) do x
            if @capture(x, (a_ + b_))
                return :(sum($a, $b))
            else
                return x
            end
        end

        @test_expression_generating result output

        #Test 3: walk with guard function that always returns true
        g_walk = guarded_walk((x) -> true)

        input = quote
            x[i+1] + 1
        end

        result = g_walk(input) do x
            if @capture(x, (a_ + b_))
                return :(sum($a, $b))
            else
                return x
            end
        end

        @test_expression_generating result input

    end

    @testset "save_expression_in_tilde" begin
        import GraphPPL: save_expression_in_tilde, apply_pipeline

        input = :(x ~ Normal(0, 1))
        output = :(x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))})
        @test save_expression_in_tilde(input) == output

        input = quote
            x ~ Normal(0, 1)
            y ~ Normal(0, 1)
        end

        output = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end

        @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output

        input = :(x .~ Normal(0, 1))
        output = :(x .~ Normal(0, 1) where {created_by=(x.~Normal(0, 1))})
        @test save_expression_in_tilde(input) == output

        input = quote
            x .~ Normal(0, 1)
            y .~ Normal(0, 1)
        end

        output = quote
            x .~ Normal(0, 1) where {created_by=(x.~Normal(0, 1))}
            y .~ Normal(0, 1) where {created_by=(y.~Normal(0, 1))}
        end

        @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output


        input = :(x := Normal(0, 1))
        output = :(x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))})
        @test save_expression_in_tilde(input) == output

        input = quote
            x := Normal(0, 1)
            y := Normal(0, 1)
        end

        output = quote
            x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))}
            y := Normal(0, 1) where {created_by=(y:=Normal(0, 1))}
        end

        @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output


        input = quote
            x ~ Normal(0, 1) where {q=MeanField()}
            y ~ Normal(0, 1) where {q=MeanField()}
        end

        output = quote
            x ~ Normal(
                0,
                1,
            ) where {q=MeanField(),created_by=(x~Normal(0, 1) where {q=MeanField()})}
            y ~ Normal(
                0,
                1,
            ) where {q=MeanField(),created_by=(y~Normal(0, 1) where {q=MeanField()})}
        end

        @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output

        # Test with different variable names
        input = :(y ~ Normal(0, 1))
        output = :(y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))})
        @test save_expression_in_tilde(input) == output

        input = :(z ~ Normal(0, 1))
        output = :(z ~ Normal(0, 1) where {created_by=(z~Normal(0, 1))})
        @test save_expression_in_tilde(input) == output

        # Test with different parameter options
        input = :(x ~ Normal(0, 1) where {mu=2.0,sigma=0.5})
        output = :(
            x ~ Normal(
                0,
                1,
            ) where {
                mu=2.0,
                sigma=0.5,
                created_by=(x~Normal(0, 1) where {mu=2.0,sigma=0.5}),
            }
        )
        @test save_expression_in_tilde(input) == output

        input = :(y ~ Normal(0, 1) where {mu=1.0})
        output =
            :(y ~ Normal(0, 1) where {mu=1.0,created_by=(y~Normal(0, 1) where {mu=1.0})})
        @test save_expression_in_tilde(input) == output

        # Test with no parameter options
        input = :(x ~ Normal(0, 1) where {})
        output = :(x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1) where {})})

        input = quote
            for i = 1:10
                println(i)
                call_some_weird_function()
                x = i
            end
        end
        @test_expression_generating save_expression_in_tilde(input) input

        input = quote
            for i = 1:10
                x[i] ~ Normal(0, 1)
            end
        end
        output = quote
            for i = 1:10
                x[i] ~ Normal(0, 1) where {created_by=(x[i]~Normal(0, 1))}
            end
        end
        @test_expression_generating save_expression_in_tilde(input) input


        input = quote
            local x ~ Normal(0, 1)
            local y ~ Normal(0, 1)
        end

        output = quote
            local x ~ Normal(0, 1) where {created_by=(local x ~ Normal(0, 1))}
            local y ~ Normal(0, 1) where {created_by=(local y ~ Normal(0, 1))}
        end

        @test_broken prettify(apply_pipeline(input, save_expression_in_tilde)) ==
                     prettify(output)
    end

    @testset "convert_deterministic_statement" begin
        import GraphPPL: convert_deterministic_statement, apply_pipeline

        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_deterministic_statement) input

        input = quote
            x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))}
            y := Normal(0, 1) where {created_by=(y:=Normal(0, 1))}
        end
        output = quote
            x ~ Normal(0, 1) where {created_by=(x:=Normal(0, 1)),is_deterministic=true}
            y ~ Normal(0, 1) where {created_by=(y:=Normal(0, 1)),is_deterministic=true}
        end
        @test_expression_generating apply_pipeline(input, convert_deterministic_statement) output

        # Test case 4: Input expression with multiple matching patterns
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y := Normal(0, 1) where {created_by=(y:=Normal(0, 1))}
            z ~ Bernoulli(0.5) where {created_by=(z:=Bernoulli(0.5))}
        end
        # Expected output: Modified expressions with added `is_deterministic = true` option
        output = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y ~ Normal(0, 1) where {created_by=(y:=Normal(0, 1)),is_deterministic=true}
            z ~ Bernoulli(0.5) where {created_by=(z:=Bernoulli(0.5))}
        end
        @test_expression_generating apply_pipeline(input, convert_deterministic_statement) output

    end

    @testset "convert_local_statement" begin
        import GraphPPL: convert_local_statement, apply_pipeline

        input = quote
            local x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            x = GraphPPL.add_variable_node!(model, context, gensym(:x))
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_local_statement) output


        input = quote
            local x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            local y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        output = quote
            x = GraphPPL.add_variable_node!(model, context, gensym(:x))
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y = GraphPPL.add_variable_node!(model, context, gensym(:y))
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_local_statement) output

        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            local y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        output = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y = GraphPPL.add_variable_node!(model, context, gensym(:y))
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_local_statement) output
    end

    @testset "convert_to_kwargs_expression" begin
        import GraphPPL: convert_to_kwargs_expression, apply_pipeline
        #Test 1: Input expression with no matching patterns
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        #Test 2: Input expression with one matching pattern
        input = quote
            x ~ Normal(μ = y, σ = z) where {created_by=(x~Normal(μ = y, σ = z))}
        end
        output = quote
            x ~ Normal(; μ = y, σ = z) where {created_by=(x~Normal(μ = y, σ = z))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        #Test 3: Input expression with no matching pattern
        input = quote
            x .~ f(a, b; c = 1, d = 2) where {created_by=(x.~f(a, b; c = 1, d = 2))}
        end
        output = quote
            x .~ f(a, b; c = 1, d = 2) where {created_by=(x.~f(a, b; c = 1, d = 2))}
        end
        @test_expression_generating convert_to_kwargs_expression(input) output

        #Test 4: Input expression with multiple matching patterns
        input = quote
            x ~ Normal(μ = y, σ = z) where {created_by=(x~Normal(μ = y, σ = z))}
            y ~ Normal(μ = x, σ = z) where {created_by=(y~Normal(μ = x, σ = z))}
        end

        output = quote
            x ~ Normal(; μ = y, σ = z) where {created_by=(x~Normal(μ = y, σ = z))}
            y ~ Normal(; μ = x, σ = z) where {created_by=(y~Normal(μ = x, σ = z))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

    end

    @testset "convert_indexed_statement" begin
        import GraphPPL: convert_indexed_statement, apply_pipeline

        #Test 1: Input expression with a single vector definition
        input = quote
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x, 1)
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_indexed_statement) output

        #Test 2: Input expression with a single tensor definition
        input = quote
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x, 1, 2)
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_indexed_statement) output

        #Test 3: Input expression with a single vector definition and a single tensor definition
        input = quote
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
            y[1, 2] ~ Normal(0, 1) where {created_by=(y[1, 2]~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x, 1)
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
            y = @isdefined(y) ? y : GraphPPL.getorcreate!(model, context, :y, 1, 2)
            y[1, 2] ~ Normal(0, 1) where {created_by=(y[1, 2]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_indexed_statement) output

        #Test 4: Make sure right-hand-side indexing expressions are not converted
        input = quote
            x ~ Normal(μ[1], σ[1]) where {created_by=(x~Normal(μ[1], σ[1]))}
        end
        output = quote
            x ~ Normal(μ[1], σ[1]) where {created_by=(x~Normal(μ[1], σ[1]))}
        end
        @test_expression_generating apply_pipeline(input, convert_indexed_statement) output
    end

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

    @testset "add_get_or_create_expression" begin
        import GraphPPL: add_get_or_create_expression, apply_pipeline
        #Test 1: test scalar variable
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x)
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

        #Test 2: test vector variable 
        input = quote
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        output = quote
            GraphPPL.getorcreate!(model, context, :x, 1)
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

        #Test 3: test matrix variable
        input = quote
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        output = quote
            GraphPPL.getorcreate!(model, context, :x, 1, 2)
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output
    end

    @testset "generate_get_or_create" begin
        import GraphPPL: generate_get_or_create, apply_pipeline
        #Test 1: test scalar variable
        output = generate_get_or_create(:x)
        desired_result = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x)
        end
        @test_expression_generating output desired_result

        #Test 2: test vector variable
        output = generate_get_or_create(:x, 1)
        desired_result = quote
            GraphPPL.getorcreate!(model, context, :x, 1)
        end
        @test_expression_generating output desired_result

        #Test 3: test matrix variable
        output = generate_get_or_create(:x, (1, 2))
        desired_result = quote
            GraphPPL.getorcreate!(model, context, :x, 1, 2)
        end
        @test_expression_generating output desired_result

        #Test 4: test symbol-indexed variable
        output = generate_get_or_create(:x, :i)
        desired_result = quote
            GraphPPL.getorcreate!(model, context, :x, i)
        end
        @test_expression_generating output desired_result

        #Test 5: test symbol-indexed variable
        output = generate_get_or_create(:x, (:i, :j))
        desired_result = quote
            GraphPPL.getorcreate!(model, context, :x, i, j)
        end
        @test_expression_generating output desired_result

    end

    @testset "convert_arithmetic_operations" begin
        import GraphPPL: convert_arithmetic_operations, apply_pipeline

        #Test 1: Test regular input with all operators
        input = quote
            a + b
            a * b
            a / b
            a - b
        end
        output = quote
            sum(a, b)
            prod(a, b)
            div(a, b)
            sub(a, b)
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 2: Test input with one operator with 3 arguments
        input = quote
            a + b + c
        end
        output = quote
            sum(a, b, c)
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 3: Test input with operator inside call
        input = quote
            sin(a + b)
        end
        output = quote
            sin(sum(a, b))
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 4: Test input with nested calls 
        input = quote
            sin(a + b) + cos(a + b)
        end
        output = quote
            sum(sin(sum(a, b)), cos(sum(a, b)))
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 5: Test input with call on rhs
        input = quote
            x = a + b
        end
        output = quote
            x = sum(a, b)
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 6: Test input with mixed operators
        input = quote
            a + b * c
        end
        output = quote
            sum(a, prod(b, c))
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 7: Test input with mixed operators but different order
        input = quote
            a * b + c
        end
        output = quote
            sum(prod(a, b), c)
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 8: Test input with mixed operators and parentheses
        input = quote
            a * (b + c)
        end
        output = quote
            prod(a, sum(b, c))
        end
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 9: Test input with indexed operation on the right hand side
        input = quote
            x[i] ~ Normal(x[i-1], 1)
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output

        #Test 10: Test input with indexed operation on the right hand side
        input = quote
            x[1] ~ (Normal(x[i+1], σ) where {(created_by = (x[1] ~ Normal(x[i+1], σ)))})
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_arithmetic_operations) output
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

    @testset "convert_tilde_expression" begin
        import GraphPPL: convert_tilde_expression, apply_pipeline
        using Distributions

        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            interfaces_tuple = (
                in = GraphPPL.getifcreated(model, context, (0, 1)),
                out = GraphPPL.getifcreated(model, context, x),
            )
            GraphPPL.make_node!(model, context, Normal, interfaces_tuple)
        end
        @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

        GraphPPL.interfaces(::typeof(sum), ::Val{3}) = (:μ, :σ, :out)

        input = quote
            x ~ sum(; μ = 0, σ = 1) where {created_by=(x~sum(μ = 0, σ = 1))}
        end
        output = quote
            interfaces_tuple = (
                μ = GraphPPL.getifcreated(model, context, 0),
                σ = GraphPPL.getifcreated(model, context, 1),
                out = GraphPPL.getifcreated(model, context, x),
            )
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end
        @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

        input = quote
            x[i] ~ Normal(μ[i], σ[i]) where {created_by=(x[i]~Normal(μ[i], σ[i]))}
        end
        output = quote
            interfaces_tuple = (
                in = GraphPPL.getifcreated(model, context, (μ[i], σ[i])),
                out = GraphPPL.getifcreated(model, context, x[i]),
            )
            GraphPPL.make_node!(model, context, Normal, interfaces_tuple)
        end
        @test_expression_generating apply_pipeline(input, convert_tilde_expression) output
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
