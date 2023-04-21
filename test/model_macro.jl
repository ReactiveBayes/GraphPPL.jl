module test_model_macro

using Test
using GraphPPL
using Graphs
using TestSetExtensions
using MacroTools


@testset ExtendedTestSet "model_macro" begin

    @testset "__guard_f" begin
        import GraphPPL.__guard_f

        f(e::Expr) = 10
        @test __guard_f(f, 1) == 1
        @test __guard_f(f, :(1 + 1)) == 10
    end

    @testset "apply_pipeline" begin
        import GraphPPL: apply_pipeline
        function pipeline(e::Expr)
            if e.head == :call
                return Expr(:call, e.args[1], e.args[2], e.args[3] + 1)
            else
                return e
            end
        end
        input = quote
            x + 1
        end
        output = quote
            x + 2
        end
        @test_expression_generating apply_pipeline(input, pipeline) output
    end

    @testset "warn_datavar_constvar_randomvar" begin
        import GraphPPL: warn_datavar_constvar_randomvar, apply_pipeline

        # Test 1: test that datavar throws a warning
        input = quote
            x = datavar(Float64)
            x ~ Normal(0, 1)
        end
        @test_logs (
            :warn,
            "datavar, constvar and randomvar syntax are deprecated and will not be supported in the future. Please use the tilde syntax instead.",
        ) apply_pipeline(input, warn_datavar_constvar_randomvar)

        # Test 2: test that constvar throws a warning
        input = quote
            x = constvar(1.0)
            x ~ Normal(0, 1)
        end
        @test_logs (
            :warn,
            "datavar, constvar and randomvar syntax are deprecated and will not be supported in the future. Please use the tilde syntax instead.",
        ) apply_pipeline(input, warn_datavar_constvar_randomvar)

        # Test 3: test that randomvar throws a warning
        input = quote
            x = randomvar(Normal(0, 1))
            x ~ Normal(0, 1)
        end
        @test_logs (
            :warn,
            "datavar, constvar and randomvar syntax are deprecated and will not be supported in the future. Please use the tilde syntax instead.",
        ) apply_pipeline(input, warn_datavar_constvar_randomvar)

        # Test 4: test that tilde syntax does not throw a warning
        input = quote
            x ~ Normal(0, 1)
        end
        @test apply_pipeline(input, warn_datavar_constvar_randomvar) == input
    end

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

        #Test 4: walk with guard function that should not go into body if created_by is key
        g_walk = guarded_walk((x) -> x isa Expr && :created_by ∈ x.args)
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        output = quote
            sum(x, Normal(0, 1) where {created_by=(x~Normal(0, 1))})
            sum(y, Normal(0, 1) where {created_by=(y~Normal(0, 1))})
        end
        result = g_walk(input) do x
            if @capture(x, (a_ ~ b_))
                return :(sum($a, $b))
            else
                return x
            end
        end
        @test_expression_generating result output
    end

    @testset "walk_until_occurrence" begin
        import GraphPPL: walk_until_occurrence

        #Test 1: walk until occurrence of a specific node
        w_u_o = walk_until_occurrence(:(lhs_ ~ rhs_ where {options__}))
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        output = quote
            sum(x, Normal(0, 1) where {created_by=(x~Normal(0, 1))})
            sum(y, Normal(0, 1) where {created_by=(y~Normal(0, 1))})
        end

        result = w_u_o(input) do x
            if @capture(x, (a_ ~ b_))
                return :(sum($a, $b))
            else
                return x
            end
        end
        @test_expression_generating result output

        #Test 2: walk with nested pattern where we pattern match only once
        w_u_o = walk_until_occurrence(:(lhs_ ~ rhs_ where {options__}))
        input = quote
            x ~ Normal(
                begin
                    y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
                end,
                1,
            ) where {created_by=(x~Normal(0, 1))}
        end
        local counter = 0
        result = w_u_o(input) do x
            if @capture(x, lhs_ ~ fform_(rhs__) where {options__})
                counter += 1
            end
            return x
        end
        @test counter == 1

        # Test 3: multi line walk with 
        w_u_o = walk_until_occurrence(:(lhs_ ~ rhs_ where {options__}))
        input = quote
            x ~ Normal(
                begin
                    y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
                end,
                1,
            ) where {created_by=(x~Normal(0, 1))}
            x ~ Normal(
                begin
                    y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
                end,
                1,
            ) where {created_by=(x~Normal(0, 1))}
        end
        local counter = 0
        result = w_u_o(input) do x
            if @capture(x, lhs_ ~ fform_(rhs__) where {options__})
                counter += 1
            end
            return x
        end
        @test counter == 2

        # Test 4: walk with nested pattern where we have multiple patterns
        w_u_o = walk_until_occurrence((
            (:(lhs_ ~ rhs_ where {options__})),
            (:(local lhs_ ~ rhs_ where {options__})),
        ))
        input = quote
            x ~ Normal(
                begin
                    y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
                end,
                1,
            ) where {created_by=(x~Normal(0, 1))}
            local x ~ Normal(
                begin
                    y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
                end,
                1,
            ) where {created_by=(x~Normal(0, 1))}
        end
        local counter = 0
        result = w_u_o(input) do x
            if @capture(
                x,
                (lhs_ ~ fform_(rhs__) where {options__}) |
                (local lhs_ ~ fform_(rhs__) where {options__})
            )
                counter += 1
            end
            return x
        end
        @test counter == 2


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

        @test_expression_generating save_expression_in_tilde(input) input
    end

    @testset "get_created_by" begin
        import GraphPPL.get_created_by

        # Test 1: only created by
        input = [:(created_by = (x ~ Normal(0, 1)))]
        @test get_created_by(input) == :(x ~ Normal(0, 1))

        # Test 2: created by and other parameters
        input = [:(created_by = (x ~ Normal(0, 1))), :(q = MeanField())]
        @test get_created_by(input) == :(x ~ Normal(0, 1))

        # Test 3: created by and other parameters
        input =
            [:(created_by = (x ~ Normal(0, 1) where {q} = MeanField())), :(q = MeanField())]
        @test_expression_generating get_created_by(input) :(
            x ~ Normal(0, 1) where {q} = MeanField()
        )

        @test_throws ErrorException get_created_by([:(q = MeanField())])

    end

    @testset "convert_deterministic_statement" begin
        import GraphPPL: convert_deterministic_statement, apply_pipeline

        # Test 1: no deterministic statement
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_deterministic_statement) input

        # Test 2: deterministic statement
        input = quote
            x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))}
            y := Normal(0, 1) where {created_by=(y:=Normal(0, 1))}
        end
        output = quote
            x ~ Normal(0, 1) where {created_by=(x:=Normal(0, 1)),is_deterministic=true}
            y ~ Normal(0, 1) where {created_by=(y:=Normal(0, 1)),is_deterministic=true}
        end
        @test_expression_generating apply_pipeline(input, convert_deterministic_statement) output

        # Test case 3: Input expression with multiple matching patterns
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

        # Test 1: one local statement
        input = quote
            local x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            x = GraphPPL.add_variable_node!(model, context, gensym(model, :x))
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_local_statement) output

        # Test 2: two local statements
        input = quote
            local x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            local y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        output = quote
            x = GraphPPL.add_variable_node!(model, context, gensym(model, :x))
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y = GraphPPL.add_variable_node!(model, context, gensym(model, :y))
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_local_statement) output

        # Test 3: mixed local and non-local statements
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            local y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        output = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
            y = GraphPPL.add_variable_node!(model, context, gensym(model, :y))
            y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_local_statement) output
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

        kwargs = :(foo(; a = a, b = b))
        @capture(kwargs, (f_(args__)))
        @test is_kwargs_expression(args)

        mixed_args = :(foo(a, b; c = c))
        @capture(mixed_args, (f_(args__)))
        @test !is_kwargs_expression(args)
    end

    @testset "convert_to_kwargs_expression" begin
        import GraphPPL: convert_to_kwargs_expression, apply_pipeline

        # Test 1: Input expression with ~ expression and args and kwargs expressions
        input = quote
            x ~ Normal(0, 1; a = 1, b = 2) where {created_by=(x~Normal(0, 1; a = 1, b = 2))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 2: Input expression with ~ expression and args and kwargs expressions with symbols
        input = quote
            x ~ Normal(μ, σ; a = τ, b = θ) where {created_by=(x~Normal(μ, σ; a = τ, b = θ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 3: Input expression with ~ expression and only kwargs expression
        input = quote
            x ~ Normal(; a = 1, b = 2) where {created_by=(x~Normal(; a = 1, b = 2))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 4: Input expression with ~ expression and only kwargs expression with symbols
        input = quote
            x ~ Normal(; a = τ, b = θ) where {created_by=(x~Normal(; a = τ, b = θ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 5: Input expression with ~ expression and only args expression
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 6: Input expression with ~ expression and only args expression with symbols
        input = quote
            x ~ Normal(μ, σ) where {created_by=(x~Normal(μ, σ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 7: Input expression with ~ expression and named args expression
        input = quote
            x ~ Normal(μ = 0, σ = 1) where {created_by=(x~Normal(μ = 0, σ = 1))}
        end
        output = quote
            x ~ Normal(; μ = 0, σ = 1) where {created_by=(x~Normal(μ = 0, σ = 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 8: Input expression with ~ expression and named args expression with symbols
        input = quote
            x ~ Normal(μ = μ, σ = σ) where {created_by=(x~Normal(μ = μ, σ = σ))}
        end
        output = quote
            x ~ Normal(; μ = μ, σ = σ) where {created_by=(x~Normal(μ = μ, σ = σ))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output


        # Test 9: Input expression with .~ expression and args and kwargs expressions
        input = quote
            x .~ Normal(0, 1; a = 1, b = 2) where {created_by=(x.~Normal(0, 1; a = 1, b = 2))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 10: Input expression with .~ expression and args and kwargs expressions with symbols
        input = quote
            x .~ Normal(μ, σ; a = τ, b = θ) where {created_by=(x.~Normal(μ, σ; a = τ, b = θ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 11: Input expression with .~ expression and only kwargs expression
        input = quote
            x .~ Normal(; a = 1, b = 2) where {created_by=(x.~Normal(; a = 1, b = 2))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 12: Input expression with .~ expression and only kwargs expression with symbols
        input = quote
            x .~ Normal(; a = τ, b = θ) where {created_by=(x.~Normal(; a = τ, b = θ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 13: Input expression with .~ expression and only args expression
        input = quote
            x .~ Normal(0, 1) where {created_by=(x.~Normal(0, 1))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 14: Input expression with .~ expression and only args expression with symbols
        input = quote
            x .~ Normal(μ, σ) where {created_by=(x.~Normal(μ, σ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 15: Input expression with .~ expression and named args expression
        input = quote
            x .~ Normal(μ = 0, σ = 1) where {created_by=(x.~Normal(μ = 0, σ = 1))}
        end
        output = quote
            x .~ Normal(; μ = 0, σ = 1) where {created_by=(x.~Normal(μ = 0, σ = 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 16: Input expression with .~ expression and named args expression with symbols
        input = quote
            x .~ Normal(μ = μ, σ = σ) where {created_by=(x.~Normal(μ = μ, σ = σ))}
        end
        output = quote
            x .~ Normal(; μ = μ, σ = σ) where {created_by=(x.~Normal(μ = μ, σ = σ))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 17: Input expression with := expression and args and kwargs expressions
        input = quote
            x := Normal(0, 1; a = 1, b = 2) where {created_by=(x:=Normal(0, 1; a = 1, b = 2))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 18: Input expression with := expression and args and kwargs expressions with symbols
        input = quote
            x := Normal(μ, σ; a = τ, b = θ) where {created_by=(x:=Normal(μ, σ; a = τ, b = θ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 19: Input expression with := expression and only kwargs expression
        input = quote
            x := Normal(; a = 1, b = 2) where {created_by=(x:=Normal(; a = 1, b = 2))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 20: Input expression with := expression and only kwargs expression with symbols
        input = quote
            x := Normal(; a = τ, b = θ) where {created_by=(x:=Normal(; a = τ, b = θ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 21: Input expression with := expression and only args expression
        input = quote
            x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 22: Input expression with := expression and only args expression with symbols
        input = quote
            x := Normal(μ, σ) where {created_by=(x:=Normal(μ, σ))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 23: Input expression with := expression and named args as args expression
        input = quote
            x := Normal(μ = 0, σ = 1) where {created_by=(x:=Normal(μ = 0, σ = 1))}
        end
        output = quote
            x := Normal(; μ = 0, σ = 1) where {created_by=(x:=Normal(μ = 0, σ = 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 24: Input expression with := expression and named args as args expression with symbols
        input = quote
            x := Normal(μ = μ, σ = σ) where {created_by=(x:=Normal(μ = μ, σ = σ))}
        end
        output = quote
            x := Normal(; μ = μ, σ = σ) where {created_by=(x:=Normal(μ = μ, σ = σ))}
        end
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 25: Input expression with ~ expression and additional arguments in where clause
        input = quote
            x ~ Normal(
                0,
                1,
            ) where {q=MeanField(),created_by=(x ~ Normal(0, 1)) where {q}=MeanField()}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

        # Test 26: Input expression with nested call in rhs
        input = quote
            x ~ Normal(Normal(0, 1)) where {created_by=(x~Normal(Normal(0, 1)))}
        end
        output = input
        @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

    end

    @testset "convert_indexed_statement" begin
        import GraphPPL: convert_indexed_statement, apply_pipeline

        #Test 1: Input expression with a single vector definition
        input = quote
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreatearray!(model, context, :x, Val(1))
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_indexed_statement) output

        #Test 2: Input expression with a single tensor definition
        input = quote
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreatearray!(model, context, :x, Val(2))
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_indexed_statement) output

        #Test 3: Input expression with a single vector definition and a single tensor definition
        input = quote
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
            y[1, 2] ~ Normal(0, 1) where {created_by=(y[1, 2]~Normal(0, 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreatearray!(model, context, :x, Val(1))
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
            y =
                @isdefined(y) ? y : GraphPPL.getorcreatearray!(model, context, :y, Val(2))
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

    @testset "convert_to_anonymous" begin
        import GraphPPL: convert_to_anonymous, apply_pipeline

        # Test 1: convert function to anonymous function
        input = quote
            Normal(0, 1)
        end
        created_by = :(x ~ Normal(0, 1))
        anon = gensym(:tmp)
        output = quote
            begin
                $anon ~ Normal(0, 1) where {anonymous=true,created_by=x~Normal(0, 1)}
                $anon
            end
        end
        @test_expression_generating convert_to_anonymous(input, created_by) output

        # Test 2: leave number expression
        input = quote
            1
        end
        created_by = :(x ~ Normal(0, 1))
        output = input
        @test_expression_generating convert_to_anonymous(input, created_by) output

        # Test 3: leave symbol expression
        input = quote
            :x
        end
        created_by = :(x ~ Normal(0, 1))
        output = input
        @test_expression_generating convert_to_anonymous(input, created_by) output
    end

    @testset "convert_function_argument_in_rhs" begin
        import GraphPPL: convert_function_argument_in_rhs, apply_pipeline

        #Test 1: Input expression with a function call in rhs arguments
        input = quote
            x ~ Normal(Normal(0, 1), 1) where {created_by=(x~Normal(Normal(0, 1), 1))}
        end
        sym = gensym(:tmp)
        output = quote
            x ~ Normal(
                begin
                    $sym ~ Normal(
                        0,
                        1,
                    ) where {anonymous=true,created_by=x~Normal(Normal(0, 1), 1)}
                    $sym
                end,
                1,
            ) where {created_by=(x~Normal(Normal(0, 1), 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 2: Input expression without pattern matching
        input = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 3: Input expression with a function call as kwargs
        input = quote
            x ~ Normal(;
                μ = Normal(0, 1),
                σ = 1,
            ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = 1))}
        end
        sym = gensym(:tmp)
        output = quote
            x ~ Normal(;
                μ = begin
                    $sym ~ Normal(
                        0,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(; μ = Normal(0, 1), σ = 1),
                    }
                    $sym
                end,
                σ = 1,
            ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 4: Input expression without pattern matching and kwargs
        input = quote
            x ~ Normal(; μ = 0, σ = 1) where {created_by=(x~Normal(μ = 0, σ = 1))}
        end
        output = quote
            x ~ Normal(; μ = 0, σ = 1) where {created_by=(x~Normal(μ = 0, σ = 1))}
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 5: Input expression with multiple function calls in rhs arguments
        input = quote
            x ~ Normal(
                Normal(0, 1),
                Normal(0, 1),
            ) where {created_by=(x~Normal(Normal(0, 1), Normal(0, 1)))}
        end
        sym1 = gensym(:tmp)
        sym2 = gensym(:tmp)
        output = quote
            x ~ Normal(
                begin
                    $sym1 ~ Normal(
                        0,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(Normal(0, 1), Normal(0, 1)),
                    }
                    $sym1
                end,
                begin
                    $sym2 ~ Normal(
                        0,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(Normal(0, 1), Normal(0, 1)),
                    }
                    $sym2
                end,
            ) where {created_by=(x~Normal(Normal(0, 1), Normal(0, 1)))}
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 6: Input expression with multiple function calls in rhs arguments and kwargs
        input = quote
            x ~ Normal(;
                μ = Normal(0, 1),
                σ = Normal(0, 1),
            ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)))}
        end
        sym1 = gensym(:tmp)
        sym2 = gensym(:tmp)
        output = quote
            x ~ Normal(;
                μ = begin
                    $sym1 ~ Normal(
                        0,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)),
                    }
                    $sym1
                end,
                σ = begin
                    $sym2 ~ Normal(
                        0,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)),
                    }
                    $sym2
                end,
            ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)))}
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 7: Input expression with nested function call in rhs arguments
        input = quote
            x ~ Normal(
                Normal(Normal(0, 1), 1),
                1,
            ) where {created_by=(x~Normal(Normal(Normal(0, 1), 1), 1))}
        end
        sym1 = gensym(:tmp)
        sym2 = gensym(:tmp)
        output = quote
            x ~ Normal(
                begin
                    $sym1 ~ Normal(
                        begin
                            $sym2 ~ Normal(
                                0,
                                1,
                            ) where {
                                anonymous=true,
                                created_by=x~Normal(Normal(Normal(0, 1), 1), 1),
                            }
                            $sym2
                        end,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(Normal(Normal(0, 1), 1), 1),
                    }
                    $sym1
                end,
                1,
            ) where {created_by=(x~Normal(Normal(Normal(0, 1), 1), 1))}
        end

        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

        #Test 8: Input expression with nested function call in rhs arguments and kwargs and additional where clause
        input = quote
            x ~ Normal(
                Normal(Normal(0, 1), 1),
                1,
            ) where {
                q=MeanField(),
                created_by=(x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()}),
            }
        end
        sym1 = gensym(:tmp)
        sym2 = gensym(:tmp)
        output = quote
            x ~ Normal(
                begin
                    $sym1 ~ Normal(
                        begin
                            $sym2 ~ Normal(
                                0,
                                1,
                            ) where {
                                anonymous=true,
                                created_by=x~Normal(
                                    Normal(Normal(0, 1), 1),
                                    1,
                                ) where {q=MeanField()},
                            }
                            $sym2
                        end,
                        1,
                    ) where {
                        anonymous=true,
                        created_by=x~Normal(
                            Normal(Normal(0, 1), 1),
                            1,
                        ) where {q=MeanField()},
                    }
                    $sym1
                end,
                1,
            ) where {
                q=MeanField(),
                created_by=(x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()}),
            }
        end
        @test_expression_generating apply_pipeline(input, convert_function_argument_in_rhs) output

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
            GraphPPL.createifnotexists!(model, context, :x, 1)
            x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

        #Test 3: test matrix variable
        input = quote
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        output = quote
            GraphPPL.createifnotexists!(model, context, :x, 1, 2)
            x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

        #Test 4: test vector variable with variable as index
        input = quote
            x[i] ~ Normal(0, 1) where {created_by=(x[i]~Normal(0, 1))}
        end
        output = quote
            GraphPPL.createifnotexists!(model, context, :x, i)
            x[i] ~ Normal(0, 1) where {created_by=(x[i]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

        #Test 5: test matrix variable with symbol as index
        input = quote
            x[i, j] ~ Normal(0, 1) where {created_by=(x[i, j]~Normal(0, 1))}
        end
        output = quote
            GraphPPL.createifnotexists!(model, context, :x, i, j)
            x[i, j] ~ Normal(0, 1) where {created_by=(x[i, j]~Normal(0, 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

        #Test 4: test function call  in parameters on rhs
        sym = gensym(:tmp)
        input = quote
            x ~ Normal(
                begin
                    $sym ~ Normal(
                        0,
                        1,
                    ) where {anonymous=true,created_by=x~Normal(Normal(0, 1), 1)}
                    $sym
                end,
                1,
            ) where {created_by=(x~Normal(Normal(0, 1), 1))}
        end
        output = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x)
            x ~ Normal(
                begin
                    $sym =
                        @isdefined($sym) ? $sym :
                        GraphPPL.getorcreate!(model, context, $(QuoteNode(sym)))
                    $sym ~ Normal(
                        0,
                        1,
                    ) where {anonymous=true,created_by=x~Normal(Normal(0, 1), 1)}
                    $sym
                end,
                1,
            ) where {created_by=(x~Normal(Normal(0, 1), 1))}
        end
        @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    end

    @testset "generate_get_or_create" begin
        import GraphPPL: generate_get_or_create, apply_pipeline
        # Test 1: test scalar variable
        output = generate_get_or_create(:x)
        desired_result = quote
            x = @isdefined(x) ? x : GraphPPL.getorcreate!(model, context, :x)
        end
        @test_expression_generating output desired_result

        # Test 2: test vector variable
        output = generate_get_or_create(:x, 1)
        desired_result = quote
            GraphPPL.createifnotexists!(model, context, :x, 1)
        end
        @test_expression_generating output desired_result

        # Test 3: test matrix variable
        output = generate_get_or_create(:x, (1, 2))
        desired_result = quote
            GraphPPL.createifnotexists!(model, context, :x, 1, 2)
        end
        @test_expression_generating output desired_result

        # Test 5: test symbol-indexed variable
        output = generate_get_or_create(:x, (:i, :j))
        desired_result = quote
            GraphPPL.createifnotexists!(model, context, :x, i, j)
        end
        @test_expression_generating output desired_result

        # Test 6: test vector of single symbol
        output = generate_get_or_create(:x, [:i])
        desired_result = quote
            GraphPPL.createifnotexists!(model, context, :x, i)
        end
        @test_expression_generating output desired_result

        # Test 7: test vector of symbols
        output = generate_get_or_create(:x, [:i, :j])
        desired_result = quote
            GraphPPL.createifnotexists!(model, context, :x, i, j)
        end
        @test_expression_generating output desired_result

        # Test 8: test error if un-unrollable index
        @test_throws MethodError generate_get_or_create(:x, 1, 2)

        # Test 9: test error if un-unrollable index
        @test_throws MethodError generate_get_or_create(:x, prod(0, 1))
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

    @testset "missing_interfaces" begin
        import GraphPPL: missing_interfaces, interfaces
        function abc end

        GraphPPL.interfaces(::typeof(abc), ::Val{3}) = [:in1, :in2, :out]

        @test missing_interfaces(abc, Val(3), (in1 = :x, in2 = :y)) == [:out]
        @test missing_interfaces(abc, Val(3), (out = :y,)) == [:in1, :in2]
        @test missing_interfaces(abc, Val(3), Dict()) == [:in1, :in2, :out]

        function xyz end

        GraphPPL.interfaces(::typeof(xyz), ::Val{0}) = []
        @test missing_interfaces(xyz, Val(0), (in1 = :x, in2 = :y)) == []

        function foo end

        GraphPPL.interfaces(::typeof(foo), ::Val{2}) = (:a, :b)
        @test missing_interfaces(foo, Val(2), (a = 1, b = 2)) == []

        function bar end
        GraphPPL.interfaces(::typeof(bar), ::Val{2}) = (:in1, :in2, :out)
        @test missing_interfaces(bar, Val(2), (in1 = 1, in2 = 2, out = 3, test = 4)) == []
    end

    @testset "prepare_interfaces" begin
        import GraphPPL: prepare_interfaces, interfaces

        function dummy end

        GraphPPL.NodeType(::typeof(dummy)) = GraphPPL.Composite()
        GraphPPL.interfaces(::typeof(dummy), ::Val{2}) = (:a, :b)

        # Test 1: Test regular input for composite node
        lhs = :x
        fform = dummy
        rhs = (a = :y,)
        @test prepare_interfaces(lhs, fform, rhs) == (a = :y, b = :x)

        # Test 2: Test illegal input for composite node
        @test_throws ErrorException prepare_interfaces(lhs, dummy, [:y])

        # Test 3: Test regular input for atomic node
        lhs = :x
        fform = sum
        rhs = [:y, :z]
        @test prepare_interfaces(lhs, fform, rhs) == (in = :((y, z)), out = :x)

        # Test 4: Test kwarg input for atomic node
        lhs = :x
        fform = sum
        rhs = (a = :y, z = :z)
        @test prepare_interfaces(lhs, fform, rhs) == (a = :y, z = :z, out = :x)

        # Test 5: Test composite node with Expr rhs
        lhs = :(x[i])
        fform = dummy
        rhs = (a = :(y[i]),)
        @test prepare_interfaces(lhs, fform, rhs) == (a = :(y[i]), b = :(x[i]))

    end

    @testset "convert_interfaces_tuple" begin
        import GraphPPL: convert_interfaces_tuple, interfaces

        # Test 1: Test regular input
        @test convert_interfaces_tuple(:a, :y) ==
              :((a = GraphPPL.getifcreated(model, context, y)))

        # Test 2: Test tuple input
        @test convert_interfaces_tuple(:in, :((0, 1))) ==
              :((in = GraphPPL.getifcreated(model, context, (0, 1))))

        # Test 3: Test input with multiple interfaces
        @test_expression_generating convert_interfaces_tuple(:b, (:x, :y, :z)) :((
            b = GraphPPL.getifcreated(model, context, $(:x, :y, :z))
        ))

        # Test 4: Test tuple input with symbols
        @test convert_interfaces_tuple(:in, :((y, z))) ==
              :((in = GraphPPL.getifcreated(model, context, (y, z))))

        # Test 5: Test input with a nested tuple
        @test convert_interfaces_tuple(:d, :((0, (1, 2), 3))) ==
              :((d = GraphPPL.getifcreated(model, context, (0, (1, 2), 3))))

    end

    @testset "keyword_expressions_to_named_tuple" begin
        import GraphPPL:
            keyword_expressions_to_named_tuple, apply_pipeline, convert_to_kwargs_expression

        expr = [:($(Expr(:kw, :in1, :y))), :($(Expr(:kw, :in2, :z)))]
        @test keyword_expressions_to_named_tuple(expr) == (; zip((:in1, :in2), (:y, :z))...)

        expr = quote
            x ~ Normal(; μ = 0, σ = 1)
        end
        @capture(expr, (lhs_ ~ f_(; kwargs__)))
        @test keyword_expressions_to_named_tuple(kwargs) == (; zip((:μ, :σ), (0, 1))...)

        input = quote
            x ~ Normal(0, 1; a = 1, b = 2) where {created_by=(x~Normal(0, 1; a = 1, b = 2))}
        end
        @capture(input, (lhs_ ~ f_(args__; kwargs__) where {options__}))
        @test keyword_expressions_to_named_tuple(kwargs) == (; zip((:a, :b), (1, 2))...)

        input = quote
            x ~ Normal(μ, σ; a = 1, b = 2) where {created_by=(x~Normal(μ, σ; a = 1, b = 2))}
        end
        @capture(input, (lhs_ ~ f_(args__; kwargs__) where {options__}))
        @test keyword_expressions_to_named_tuple(kwargs) == (; zip((:a, :b), (1, 2))...)
    end

    @testset "convert_tilde_expression" begin
        import GraphPPL: convert_tilde_expression, apply_pipeline
        function Normal end

        # Test 1: Test regular node creation input
        input = quote
            x ~ sum(0, 1) where {created_by=(x~Normal(0, 1))}
        end
        output = quote
            interfaces_tuple = (
                in = GraphPPL.getifcreated(model, context, (0, 1)),
                out = GraphPPL.getifcreated(model, context, x),
            )
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end
        @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

        # Test 2: Test regular node creation input with kwargs
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

        # Test 3: Test regular node creation with indexed input
        input = quote
            x[i] ~ sum(μ[i], σ[i]) where {created_by=(x[i]~sum(μ[i], σ[i]))}
        end
        output = quote
            interfaces_tuple = (
                in = GraphPPL.getifcreated(model, context, (μ[i], σ[i])),
                out = GraphPPL.getifcreated(model, context, x[i]),
            )
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
        end
        @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

        # Test 4: Test node creation with anonymous variable
        input = quote
            x ~ sum(
                begin
                    tmp_1 ~ sum(;
                        in = (0, 1),
                    ) where {anonymous=true,created_by=(x~Normal(Normal(0, 1), 0))}
                    tmp_1
                end,
                0,
            ) where {created_by=(x~Normal(Normal(0, 1), 0))}
        end
        output = quote
            interfaces_tuple = (
                in = GraphPPL.getifcreated(
                    model,
                    context,
                    (
                        begin
                            interfaces_tuple = (
                                in = GraphPPL.getifcreated(model, context, (0, 1)),
                                out = GraphPPL.getifcreated(model, context, tmp_1),
                            )
                            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
                            tmp_1
                        end,
                        0,
                    ),
                ),
                out = GraphPPL.getifcreated(model, context, x),
            )
            GraphPPL.make_node!(model, context, sum, interfaces_tuple)
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
