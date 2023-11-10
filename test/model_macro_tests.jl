@testitem "__guard_f" begin
    import GraphPPL.__guard_f

    f(e::Expr) = 10
    @test __guard_f(f, 1) == 1
    @test __guard_f(f, :(1 + 1)) == 10
end

@testitem "apply_pipeline" begin
    include("model_zoo.jl")
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

@testitem "check_reserved_variable_names_model" begin
    import GraphPPL: apply_pipeline, check_reserved_variable_names_model

    # Test 1: test that reserved variable name __parent_options__ throws an error
    input = quote
        __parent_options__ = 1
        x ~ Normal(0, 1)
    end
    @test_throws ErrorException apply_pipeline(input, check_reserved_variable_names_model)

    # Test 2: test that reserved variable name __debug__ throws an error
    input = quote
        __debug__ = 1
        x ~ Normal(0, 1)
    end
    @test_throws ErrorException apply_pipeline(input, check_reserved_variable_names_model)

    # Test 3: test that other variable names do not throw an error
    input = quote
        x = 1
        x ~ Normal(0, 1)
    end
    @test apply_pipeline(input, check_reserved_variable_names_model) == input
end

@testitem "check_incomplete_factorization_constraint" begin
    import GraphPPL: apply_pipeline, check_incomplete_factorization_constraint

    input = quote
        q(x)q(y)
    end
    @test_throws ErrorException apply_pipeline(
        input,
        check_incomplete_factorization_constraint,
    )

    input = quote
        q(x)q(y)q(z)
    end
    @test_throws ErrorException apply_pipeline(
        input,
        check_incomplete_factorization_constraint,
    )

    input = quote
        q(x)
    end
    @test_throws ErrorException apply_pipeline(
        input,
        check_incomplete_factorization_constraint,
    )

    input = quote
        q(x, y, z) = q(x)q(y)q(z)
    end
    @test apply_pipeline(input, check_incomplete_factorization_constraint) == input

    input = quote
        q(x)::MeanField()
    end
    @test apply_pipeline(input, check_incomplete_factorization_constraint) == input

end

@testitem "check_for_returns" begin
    import GraphPPL: check_for_returns, apply_pipeline

    input = quote
        x = 1
        return x
    end
    @test_throws ErrorException("The model macro does not support return statements.") apply_pipeline(
        input,
        check_for_returns,
    )

    input = quote
        x = 1
        return
    end
    @test_throws ErrorException("The model macro does not support return statements.") apply_pipeline(
        input,
        check_for_returns,
    )

    input = quote
        x = 1
    end
    @test apply_pipeline(input, check_for_returns) == input
end

@testitem "warn_datavar_constvar_randomvar" begin
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

@testitem "guarded_walk" begin
    include("model_zoo.jl")
    import MacroTools: @capture
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

@testitem "save_expression_in_tilde" begin
    include("model_zoo.jl")
    import GraphPPL: save_expression_in_tilde, apply_pipeline

    # Test 1: save expression in tilde
    input = :(x ~ Normal(0, 1))
    output = :(x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))})
    @test save_expression_in_tilde(input) == output

    # Test 2: save expression in tilde with multiple expressions
    input = quote
        x ~ Normal(0, 1)
        y ~ Normal(0, 1)
    end
    output = quote
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output

    # Test 3: save expression in tilde with broadcasted operation
    input = :(x .~ Normal(0, 1))
    output = :(x .~ Normal(0, 1) where {created_by=(x.~Normal(0, 1))})
    @test save_expression_in_tilde(input) == output

    # Test 4: save expression in tilde with multiple broadcast expressions
    input = quote
        x .~ Normal(0, 1)
        y .~ Normal(0, 1)
    end

    output = quote
        x .~ Normal(0, 1) where {created_by=(x.~Normal(0, 1))}
        y .~ Normal(0, 1) where {created_by=(y.~Normal(0, 1))}
    end

    @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output

    # Test 5: save expression in tilde with deterministic operation
    input = :(x := Normal(0, 1))
    output = :(x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))})
    @test save_expression_in_tilde(input) == output

    # Test 6: save expression in tilde with multiple deterministic expressions
    input = quote
        x := Normal(0, 1)
        y := Normal(0, 1)
    end

    output = quote
        x := Normal(0, 1) where {created_by=(x:=Normal(0, 1))}
        y := Normal(0, 1) where {created_by=(y:=Normal(0, 1))}
    end

    @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output

    # Test 7: save expression in tilde with additional options
    input = quote
        x ~ Normal(0, 1) where {q=MeanField()}
        y ~ Normal(0, 1) where {q=MeanField()}
    end
    output = quote
        x ~ Normal(0, 1) where {q=MeanField(),created_by=(x~Normal(0, 1) where {q=MeanField()})}
        y ~ Normal(
            0,
            1,
        ) where {q=MeanField(),created_by=(y~Normal(0, 1) where {q=MeanField()})}
    end
    @test_expression_generating apply_pipeline(input, save_expression_in_tilde) output

    # Test 8: with different variable names
    input = :(y ~ Normal(0, 1))
    output = :(y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))})
    @test save_expression_in_tilde(input) == output

    # Test 9: with different parameter options
    input = :(x ~ Normal(0, 1) where {mu=2.0,sigma=0.5})
    output = :(
        x ~ Normal(
            0,
            1,
        ) where {mu=2.0,sigma=0.5,created_by=(x~Normal(0, 1) where {mu=2.0,sigma=0.5})}
    )
    @test save_expression_in_tilde(input) == output

    # Test 10: with different parameter options
    input = :(y ~ Normal(0, 1) where {mu=1.0})
    output = :(y ~ Normal(0, 1) where {mu=1.0,created_by=(y~Normal(0, 1) where {mu=1.0})})
    @test save_expression_in_tilde(input) == output

    # Test 11: with no parameter options
    input = :(x ~ Normal(0, 1) where {})
    output = :(x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1) where {})})

    # Test 12: check unmatching pattern
    input = quote
        for i = 1:10
            println(i)
            call_some_weird_function()
            x = i
        end
    end
    @test_expression_generating save_expression_in_tilde(input) input

    # Test 13: check matching pattern in loop
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


    # Test 14: check local statements
    input = quote
        local x ~ Normal(0, 1)
        local y ~ Normal(0, 1)
    end

    output = quote
        local x ~ (Normal(0, 1)) where {created_by=(local x ~ Normal(0, 1))}
        local y ~ (Normal(0, 1)) where {created_by=(local y ~ Normal(0, 1))}
    end

    @test_expression_generating save_expression_in_tilde(input) input

    # Test 15: check arithmetic operations
    input = quote
        x := a + b
    end
    output = quote
        x := (a + b) where {created_by=(x:=a+b)}
    end
    @test_expression_generating save_expression_in_tilde(input) output

end

@testitem "get_created_by" begin
    include("model_zoo.jl")
    import GraphPPL.get_created_by

    # Test 1: only created by
    input = [:(created_by = (x ~ Normal(0, 1)))]
    @test get_created_by(input) == :(x ~ Normal(0, 1))

    # Test 2: created by and other parameters
    input = [:(created_by = (x ~ Normal(0, 1))), :(q = MeanField())]
    @test get_created_by(input) == :(x ~ Normal(0, 1))

    # Test 3: created by and other parameters
    input = [:(created_by = (x ~ Normal(0, 1) where {q} = MeanField())), :(q = MeanField())]
    @test_expression_generating get_created_by(input) :(
        x ~ Normal(0, 1) where {q} = MeanField()
    )

    @test_throws ErrorException get_created_by([:(q = MeanField())])

end

@testitem "convert_deterministic_statement" begin
    include("model_zoo.jl")
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
    output = quote
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        y ~ Normal(0, 1) where {created_by=(y:=Normal(0, 1)),is_deterministic=true}
        z ~ Bernoulli(0.5) where {created_by=(z:=Bernoulli(0.5))}
    end
    @test_expression_generating apply_pipeline(input, convert_deterministic_statement) output

    # Test case 5: Input expression with multiple matching patterns
    input = quote
        x := (a + b) where {q=q(x)q(a)q(b),created_by=(x:=a+b where {q=q(x)q(a)q(b)})}
    end
    output = quote
        x ~ (
            a + b
        ) where {
            q=q(x)q(a)q(b),
            created_by=(x:=a+b where {q=q(x)q(a)q(b)}),
            is_deterministic=true,
        }
    end
    @test_expression_generating apply_pipeline(input, convert_deterministic_statement) output

end

@testitem "convert_local_statement" begin
    include("model_zoo.jl")
    import GraphPPL: convert_local_statement, apply_pipeline

    # Test 1: one local statement
    input = quote
        local x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    output = quote
        x = GraphPPL.add_variable_node!(__model__, __context__, gensym(__model__, :x))
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, convert_local_statement) output

    # Test 2: two local statements
    input = quote
        local x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        local y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
    end
    output = quote
        x = GraphPPL.add_variable_node!(__model__, __context__, gensym(__model__, :x))
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
        y = GraphPPL.add_variable_node!(__model__, __context__, gensym(__model__, :y))
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
        y = GraphPPL.add_variable_node!(__model__, __context__, gensym(__model__, :y))
        y ~ Normal(0, 1) where {created_by=(y~Normal(0, 1))}
    end

    @test_expression_generating apply_pipeline(input, convert_local_statement) output
    #Test 4: local statement with multiple matching patterns
    input = quote
        local x ~ Normal(
            a,
            b,
        ) where {q=q(x)q(a)q(b),created_by=(x~Normal(a, b) where {q=q(x)q(a)q(b)})}
    end
    output = quote
        x = GraphPPL.add_variable_node!(__model__, __context__, gensym(__model__, :x))
        x ~ Normal(
            a,
            b,
        ) where {q=q(x)q(a)q(b),created_by=(x~Normal(a, b) where {q=q(x)q(a)q(b)})}
    end
    @test_expression_generating apply_pipeline(input, convert_local_statement) output

    # Test 5: local statement with broadcasting statement
    input = quote
        local x .~ Normal(μ, σ) where {created_by=(x.~Normal(μ, σ))}
    end
    output = quote
        x .~ Normal(μ, σ) where {created_by=(x.~Normal(μ, σ))}
    end
    @test_expression_generating apply_pipeline(input, convert_local_statement) output
end

@testitem "is_kwargs_expression(::AbstractArray)" begin
    import MacroTools: @capture
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

@testitem "convert_to_kwargs_expression" begin
    include("model_zoo.jl")
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

    # Test 27: Input expression with additional where clause on rhs
    input = quote
        x ~ Normal(
            μ = μ,
            σ = σ,
        ) where {
            created_by=(x~Normal(μ = μ, σ = σ) where {q=MeanField()}),
            q=MeanField(),
        }
    end
    output = quote
        x ~ Normal(;
            μ = μ,
            σ = σ,
        ) where {
            created_by=(x~Normal(μ = μ, σ = σ) where {q=MeanField()}),
            q=MeanField(),
        }
    end
    @test_expression_generating apply_pipeline(input, convert_to_kwargs_expression) output

end


@testitem "convert_to_anonymous" begin
    include("model_zoo.jl")
    import GraphPPL: convert_to_anonymous, apply_pipeline

    # Test 1: convert function to anonymous function
    input = quote
        Normal(0, 1)
    end
    created_by = :(x ~ Normal(0, 1))
    anon = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        begin
            $anon = GraphPPL.create_anonymous_variable!(__model__, __context__)
            $anon ~ Normal(0, 1) where {anonymous=true,created_by=x~Normal(0, 1)}
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

@testitem "not_enter_indexed_walk" begin
    import GraphPPL: not_enter_indexed_walk

    # Test 1: not enter indexed walk
    input = quote
        x[1] ~ y[10+1]
    end
    result = not_enter_indexed_walk(input) do x
        @test x != 1
        return x
    end

    # Test 2: not enter indexed walk with begin or end
    input = quote
        x[begin] + x[end]
    end
    result = not_enter_indexed_walk(input) do x
        @test x != :begin && x != :end
        return x
    end
end

@testitem "convert_anonymous_variables" begin
    include("model_zoo.jl")
    using MacroTools
    import GraphPPL: convert_anonymous_variables, apply_pipeline

    #Test 1: Input expression with a function call in rhs arguments
    input = quote
        x ~ Normal(Normal(0, 1), 1) where {created_by=(x~Normal(Normal(0, 1), 1))}
    end
    sym = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x ~ Normal(
            begin
                $sym = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym ~ Normal(
                    0,
                    1,
                ) where {anonymous=true,created_by=x~Normal(Normal(0, 1), 1)}
            end,
            1,
        ) where {created_by=(x~Normal(Normal(0, 1), 1))}
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    #Test 2: Input expression without pattern matching
    input = quote
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    output = quote
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    #Test 3: Input expression with a function call as kwargs
    input = quote
        x ~ Normal(;
            μ = Normal(0, 1),
            σ = 1,
        ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = 1))}
    end
    sym = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x ~ Normal(;
            μ = begin
                $sym = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym ~ Normal(
                    0,
                    1,
                ) where {anonymous=true,created_by=x~Normal(; μ = Normal(0, 1), σ = 1)}
            end,
            σ = 1,
        ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = 1))}
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    #Test 4: Input expression without pattern matching and kwargs
    input = quote
        x ~ Normal(; μ = 0, σ = 1) where {created_by=(x~Normal(μ = 0, σ = 1))}
    end
    output = quote
        x ~ Normal(; μ = 0, σ = 1) where {created_by=(x~Normal(μ = 0, σ = 1))}
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    #Test 5: Input expression with multiple function calls in rhs arguments
    input = quote
        x ~ Normal(
            Normal(0, 1),
            Normal(0, 1),
        ) where {created_by=(x~Normal(Normal(0, 1), Normal(0, 1)))}
    end
    sym1 = MacroTools.gensym_ids(gensym(:anon))
    sym2 = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x ~ Normal(
            begin
                $sym1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym1 ~ Normal(
                    0,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(Normal(0, 1), Normal(0, 1)),
                }

            end,
            begin
                $sym2 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym2 ~ Normal(
                    0,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(Normal(0, 1), Normal(0, 1)),
                }

            end,
        ) where {created_by=(x~Normal(Normal(0, 1), Normal(0, 1)))}
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    #Test 6: Input expression with multiple function calls in rhs arguments and kwargs
    input = quote
        x ~ Normal(;
            μ = Normal(0, 1),
            σ = Normal(0, 1),
        ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)))}
    end
    sym1 = MacroTools.gensym_ids(gensym(:anon))
    sym2 = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x ~ Normal(;
            μ = begin
                $sym1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym1 ~ Normal(
                    0,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)),
                }

            end,
            σ = begin
                $sym2 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym2 ~ Normal(
                    0,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)),
                }

            end,
        ) where {created_by=(x~Normal(; μ = Normal(0, 1), σ = Normal(0, 1)))}
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    #Test 7: Input expression with nested function call in rhs arguments
    input = quote
        x ~ Normal(
            Normal(Normal(0, 1), 1),
            1,
        ) where {created_by=(x~Normal(Normal(Normal(0, 1), 1), 1))}
    end
    sym1 = MacroTools.gensym_ids(gensym(:anon))
    sym2 = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x ~ Normal(
            begin
                $sym1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym1 ~ Normal(
                    begin
                        $sym2 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                        $sym2 ~ Normal(
                            0,
                            1,
                        ) where {
                            anonymous=true,
                            created_by=x~Normal(Normal(Normal(0, 1), 1), 1),
                        }
                    end,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(Normal(Normal(0, 1), 1), 1),
                }

            end,
            1,
        ) where {created_by=(x~Normal(Normal(Normal(0, 1), 1), 1))}
    end

    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

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
    sym1 = MacroTools.gensym_ids(gensym(:anon))
    sym2 = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x ~ Normal(
            begin
                $sym1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym1 ~ Normal(
                    begin
                        $sym2 = GraphPPL.create_anonymous_variable!(__model__, __context__)
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
                    end,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()},
                }
            end,
            1,
        ) where {
            q=MeanField(),
            created_by=(x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()}),
        }
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    # Test 9: Input expression with arithmetic indexed call on rhs
    input = quote
        x ~ Normal(x[i-1], 1) where {created_by=(x~Normal(y[i-1], 1))}
    end
    output = input
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

    # Test 10: Input expression with broadcasted call
    input = quote
        x .~ Normal(
            Normal(Normal(0, 1), 1),
            1,
        ) where {
            q=MeanField(),
            created_by=(x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()}),
        }
    end
    sym1 = MacroTools.gensym_ids(gensym(:anon))
    sym2 = MacroTools.gensym_ids(gensym(:anon))
    output = quote
        x .~ Normal(
            begin
                $sym1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym1 ~ Normal(
                    begin
                        $sym2 = GraphPPL.create_anonymous_variable!(__model__, __context__)
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
                    end,
                    1,
                ) where {
                    anonymous=true,
                    created_by=x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()},
                }
            end,
            1,
        ) where {
            q=MeanField(),
            created_by=(x~Normal(Normal(Normal(0, 1), 1), 1) where {q=MeanField()}),
        }
    end
    @test_expression_generating apply_pipeline(input, convert_anonymous_variables) output

end

@testitem "add_get_or_create_expression" begin
    include("model_zoo.jl")
    import GraphPPL: add_get_or_create_expression, apply_pipeline
    #Test 1: test scalar variable
    input = quote
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    output = quote
        x =
            !@isdefined(x) ?
            GraphPPL.getorcreate!(__model__, __context__, :x, nothing) :
            (
                GraphPPL.check_variate_compatability(x, nothing) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, nothing)
            )
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    #Test 2: test vector variable 
    input = quote
        x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
    end
    output = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, 1) :
            (
                GraphPPL.check_variate_compatability(x, 1) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, 1)
            )
        x[1] ~ Normal(0, 1) where {created_by=(x[1]~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    #Test 3: test matrix variable
    input = quote
        x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
    end
    output = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, 1, 2) :
            (
                GraphPPL.check_variate_compatability(x, 1, 2) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, 1, 2)
            )
        x[1, 2] ~ Normal(0, 1) where {created_by=(x[1, 2]~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    #Test 4: test vector variable with variable as index
    input = quote
        x[i] ~ Normal(0, 1) where {created_by=(x[i]~Normal(0, 1))}
    end
    output = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, i) :
            (
                GraphPPL.check_variate_compatability(x, i) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, i)
            )
        x[i] ~ Normal(0, 1) where {created_by=(x[i]~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    #Test 5: test matrix variable with symbol as index
    input = quote
        x[i, j] ~ Normal(0, 1) where {created_by=(x[i, j]~Normal(0, 1))}
    end
    output = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, i, j) :
            (
                GraphPPL.check_variate_compatability(x, i, j) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, i, j)
            )
        x[i, j] ~ Normal(0, 1) where {created_by=(x[i, j]~Normal(0, 1))}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    #Test 4: test function call  in parameters on rhs
    sym = gensym(:anon)
    input = quote
        x ~ Normal(
            begin
                $sym ~ Normal(0, 1) where {anonymous=true,created_by=x~Normal(Normal(0, 1), 1)}
            end,
            1,
        ) where {created_by=(x~Normal(Normal(0, 1), 1))}
    end
    output = quote
        x =
            !@isdefined(x) ?
            GraphPPL.getorcreate!(__model__, __context__, :x, nothing) :
            (
                GraphPPL.check_variate_compatability(x, nothing) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, nothing)
            )
        x ~ Normal(
            begin
                $sym =
                    !@isdefined($sym) ?
                    GraphPPL.getorcreate!(
                        __model__,
                        __context__,
                        $(QuoteNode(sym)),
                        nothing,
                    ) :
                    (
                        GraphPPL.check_variate_compatability($sym, nothing) ? $sym :
                        GraphPPL.getorcreate!(
                            __model__,
                            __context__,
                            $(QuoteNode(sym)),
                            nothing,
                        )
                    )
                $sym ~ Normal(
                    0,
                    1,
                ) where {anonymous=true,created_by=x~Normal(Normal(0, 1), 1)}
            end,
            1,
        ) where {created_by=(x~Normal(Normal(0, 1), 1))}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    # Test 5: Input expression with NodeLabel on rhs
    input = quote
        y ~ x where {created_by=(y:=x),is_deterministic=true}
    end
    output = quote
        y =
            !@isdefined(y) ?
            GraphPPL.getorcreate!(__model__, __context__, :y, nothing) :
            (
                GraphPPL.check_variate_compatability(y, nothing) ? y :
                GraphPPL.getorcreate!(__model__, __context__, :y, nothing)
            )
        y ~ x where {created_by=(y:=x),is_deterministic=true}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

    # Test 6: Input expression with additional options on rhs
    input = quote
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1) where {q=q(x)q(y)}),q=q(x)q(y)}
    end
    output = quote
        x =
            !@isdefined(x) ?
            GraphPPL.getorcreate!(__model__, __context__, :x, nothing) :
            (
                GraphPPL.check_variate_compatability(x, nothing) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, nothing)
            )
        x ~ Normal(0, 1) where {created_by=(x~Normal(0, 1) where {q=q(x)q(y)}),q=q(x)q(y)}
    end
    @test_expression_generating apply_pipeline(input, add_get_or_create_expression) output

end

@testitem "generate_get_or_create" begin
    include("model_zoo.jl")
    import GraphPPL: generate_get_or_create, apply_pipeline
    # Test 1: test scalar variable
    output = generate_get_or_create(:x, :x, nothing)
    desired_result = quote
        x =
            !@isdefined(x) ?
            GraphPPL.getorcreate!(__model__, __context__, :x, nothing) :
            (
                GraphPPL.check_variate_compatability(x, nothing) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, nothing)
            )
    end
    @test_expression_generating output desired_result

    # Test 2: test vector variable
    output = generate_get_or_create(:x, :(x[1]), [1])
    desired_result = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, 1) :
            (
                GraphPPL.check_variate_compatability(x, 1) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, 1)
            )
    end
    @test_expression_generating output desired_result

    # Test 3: test matrix variable
    output = generate_get_or_create(:x, :(x[1, 2]), [1, 2])
    desired_result = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, 1, 2) :
            (
                GraphPPL.check_variate_compatability(x, 1, 2) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, 1, 2)
            )
    end
    @test_expression_generating output desired_result

    # Test 5: test symbol-indexed variable
    output = generate_get_or_create(:x, :(x[i, j]), [:i, :j])
    desired_result = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, i, j) :
            (
                GraphPPL.check_variate_compatability(x, i, j) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, i, j)
            )
    end
    @test_expression_generating output desired_result

    # Test 6: test vector of single symbol
    output = generate_get_or_create(:x, :(x[i]), [:i])
    desired_result = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, i) :
            (
                GraphPPL.check_variate_compatability(x, i) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, i)
            )
    end
    @test_expression_generating output desired_result

    # Test 7: test vector of symbols
    output = generate_get_or_create(:x, :(x[i, j]), [:i, :j])
    desired_result = quote
        x =
            !@isdefined(x) ? GraphPPL.getorcreate!(__model__, __context__, :x, i, j) :
            (
                GraphPPL.check_variate_compatability(x, i, j) ? x :
                GraphPPL.getorcreate!(__model__, __context__, :x, i, j)
            )
    end
    @test_expression_generating output desired_result

    # Test 8: test error if un-unrollable index
    @test_throws MethodError generate_get_or_create(:x, 1, 2)

    # Test 9: test error if un-unrollable index
    @test_throws MethodError generate_get_or_create(:x, prod(0, 1))
end

@testitem "missing_interfaces" begin
    include("model_zoo.jl")
    import GraphPPL: missing_interfaces, interfaces
    function abc end

    GraphPPL.interfaces(::typeof(abc), ::StaticInt{3}) = [:in1, :in2, :out]

    @test missing_interfaces(abc, static(3), (in1 = :x, in2 = :y)) == [:out]
    @test missing_interfaces(abc, static(3), (out = :y,)) == [:in1, :in2]
    @test missing_interfaces(abc, static(3), Dict()) == [:in1, :in2, :out]

    function xyz end

    GraphPPL.interfaces(::typeof(xyz), ::StaticInt{0}) = []
    @test missing_interfaces(xyz, static(0), (in1 = :x, in2 = :y)) == []

    function foo end

    GraphPPL.interfaces(::typeof(foo), ::StaticInt{2}) = (:a, :b)
    @test missing_interfaces(foo, static(2), (a = 1, b = 2)) == []

    function bar end
    GraphPPL.interfaces(::typeof(bar), ::StaticInt{2}) = (:in1, :in2, :out)
    @test missing_interfaces(bar, static(2), (in1 = 1, in2 = 2, out = 3, test = 4)) == []
end

@testitem "keyword_expressions_to_named_tuple" begin
    include("model_zoo.jl")
    import MacroTools: @capture
    import GraphPPL:
        keyword_expressions_to_named_tuple, apply_pipeline, convert_to_kwargs_expression

    expr = [:($(Expr(:kw, :in1, :y))), :($(Expr(:kw, :in2, :z)))]
    @test keyword_expressions_to_named_tuple(expr) == :((in1 = y, in2 = z))

    expr = quote
        x ~ Normal(; μ = 0, σ = 1)
    end
    @capture(expr, (lhs_ ~ f_(; kwargs__)))
    @test keyword_expressions_to_named_tuple(kwargs) == :((μ = 0, σ = 1))

    input = quote
        x ~ Normal(0, 1; a = 1, b = 2) where {created_by=(x~Normal(0, 1; a = 1, b = 2))}
    end
    @capture(input, (lhs_ ~ f_(args__; kwargs__) where {options__}))
    @test keyword_expressions_to_named_tuple(kwargs) == :((a = 1, b = 2))

    input = quote
        x ~ Normal(μ, σ; a = 1, b = 2) where {created_by=(x~Normal(μ, σ; a = 1, b = 2))}
    end
    @capture(input, (lhs_ ~ f_(args__; kwargs__) where {options__}))
    @test keyword_expressions_to_named_tuple(kwargs) == :((a = 1, b = 2))
end

@testitem "convert_tilde_expression" begin
    include("model_zoo.jl")
    import GraphPPL: convert_tilde_expression, apply_pipeline
    function Normal end

    # Test 1: Test regular node creation input
    input = quote
        x ~ sum(0, 1) where {created_by=(x~Normal(0, 1))}
    end
    output = quote
        x = GraphPPL.make_node!(
            __model__,
            __context__,
            sum,
            GraphPPL.proxylabel(:x, nothing, x),
            [0, 1];
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((created_by = :(x ~ Normal(0, 1)),))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 2: Test regular node creation input with kwargs
    input = quote
        x ~ sum(; μ = 0, σ = 1) where {created_by=(x~sum(μ = 0, σ = 1))}
    end
    output = quote
        x = GraphPPL.make_node!(
            __model__,
            __context__,
            sum,
            GraphPPL.proxylabel(:x, nothing, x),
            (μ = 0, σ = 1);
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((created_by = :(x ~ sum(μ = 0, σ = 1)),))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output


    # Test 3: Test regular node creation with indexed input
    input = quote
        x[i] ~ sum(μ[i], σ[i]) where {created_by=(x[i]~sum(μ[i], σ[i]))}
    end
    output = quote
        x[i] = GraphPPL.make_node!(
            __model__,
            __context__,
            sum,
            GraphPPL.proxylabel(:x, (i,), x),
            [μ[i], σ[i]];
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((created_by = :(x[i] ~ sum(μ[i], σ[i])),))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 4: Test node creation with anonymous variable
    input = quote
        z ~ (
            Normal(
                begin
                    anon_1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                    anon_1 ~ (
                        (x + 1) where {anonymous=true,created_by=(z~Normal(x + 1, y))}
                    )
                end,
                y,
            ) where {(created_by = (z ~ Normal(x + 1, y)))}
        )
    end
    output = quote
        z = GraphPPL.make_node!(
            __model__,
            __context__,
            Normal,
            GraphPPL.proxylabel(:z, nothing, z),
            [
                (
                    begin
                        anon_1 = GraphPPL.create_anonymous_variable!(__model__, __context__)
                        anon_1 = GraphPPL.make_node!(
                            __model__,
                            __context__,
                            +,
                            GraphPPL.proxylabel(:anon_1, nothing, anon_1),
                            [x, 1];
                            __parent_options__ = GraphPPL.prepare_options(
                                __parent_options__,
                                $(GraphPPL.FactorNodeOptions((
                                    anonymous = true,
                                    created_by = :(z ~ Normal(x + 1, y)),
                                ))),
                                __debug__,
                            ),
                            __debug__ = __debug__,
                        )
                    end
                ),
                y,
            ];
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((created_by = :(z ~ Normal(x + 1, y)),))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 5: Test node creation with non-function on rhs

    input = quote
        x ~ y where {created_by=(x:=y),is_deterministic=true}
    end
    output = quote
        x = GraphPPL.make_node!(
            __model__,
            __context__,
            y,
            GraphPPL.proxylabel(:x, nothing, x),
            $nothing;
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((
                    created_by = :(x := y),
                    is_deterministic = true,
                ))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 6: Test node creation with non-function on rhs with indexed statement

    input = quote
        x[i] ~ y where {created_by=(x[i]:=y),is_deterministic=true}
    end
    output = quote
        x[i] = GraphPPL.make_node!(
            __model__,
            __context__,
            y,
            GraphPPL.proxylabel(:x, (i,), x),
            $nothing;
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((
                    created_by = :(x[i] := y),
                    is_deterministic = true,
                ))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 7: Test node creation with non-function on rhs with multidimensional array

    input = quote
        x[i, j] ~ y where {created_by=(x[i, j]:=y),is_deterministic=true}
    end
    output = quote
        x[i, j] = GraphPPL.make_node!(
            __model__,
            __context__,
            y,
            GraphPPL.proxylabel(:x, (i, j), x),
            $nothing;
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((
                    created_by = :(x[i, j] := y),
                    is_deterministic = true,
                ))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 8: Test node creation with mixed args and kwargs on rhs
    input = quote
        x ~ sum(1, 2; σ = 1, μ = 2) where {created_by=(x~sum(1, 2; σ = 1, μ = 2))}
    end
    output = quote
        x = GraphPPL.make_node!(
            __model__,
            __context__,
            sum,
            GraphPPL.proxylabel(:x, nothing, x),
            GraphPPL.MixedArguments([1, 2], (σ = 1, μ = 2));
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((
                    created_by = :(x ~ sum(1, 2; σ = 1, μ = 2)),
                ))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 9: Test node creation with additional options
    input = quote
        x ~ sum(μ, σ) where {created_by=(x~sum(μ, σ) where {q=q(μ)q(σ)}),q=q(μ)q(σ)}
    end
    output = quote
        x = GraphPPL.make_node!(
            __model__,
            __context__,
            sum,
            GraphPPL.proxylabel(:x, nothing, x),
            [μ, σ];
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((
                    created_by = :(x ~ sum(μ, σ) where {q=q(μ)q(σ)}),
                    q = :(q(μ)q(σ)),
                ))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 10: Test node creation with kwargs and symbols_to_expression
    input = quote
        y ~ (Normal(; μ = x, σ = σ) where {(created_by = (y ~ Normal(μ = x, σ = σ)))})
    end
    output = quote
        y = GraphPPL.make_node!(
            __model__,
            __context__,
            Normal,
            GraphPPL.proxylabel(:y, nothing, y),
            (
                μ = GraphPPL.proxylabel(:x, nothing, x),
                σ = GraphPPL.proxylabel(:σ, nothing, σ),
            );
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((created_by = :(y ~ Normal(μ = x, σ = σ)),))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output
    input = quote
        y ~ prior() where {created_by=(y~prior())}
    end
    output = quote
        y = GraphPPL.make_node!(
            __model__,
            __context__,
            prior,
            GraphPPL.proxylabel(:y, nothing, y),
            [];
            __parent_options__ = GraphPPL.prepare_options(
                __parent_options__,
                $(GraphPPL.FactorNodeOptions((created_by = :(y ~ prior()),))),
                __debug__,
            ),
            __debug__ = __debug__,
        )
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 11: Test node creation with broadcasting call
    input = quote
        a .~ (Normal(μ, σ) where {(created_by = (a .~ Normal(μ, σ)))})
    end
    invars = MacroTools.gensym_ids.(gensym.((:μ, :σ)))
    output = quote
        a = broadcast(μ, σ) do $(invars...)
            return GraphPPL.make_node!(
                __model__,
                __context__,
                Normal,
                GraphPPL.Broadcasted(:a),
                [$(invars...)];
                __parent_options__ = GraphPPL.prepare_options(
                    __parent_options__,
                    $(GraphPPL.FactorNodeOptions((created_by = :(a .~ Normal(μ, σ)),))),
                    __debug__,
                ),
                __debug__ = __debug__,
            )
        end
        a = GraphPPL.ResizableArray(a)
        __context__[:a] = a
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 12: Test node creation with broadcasting call with kwargs
    input = quote
        a .~ (Normal(; μ = μ, σ = σ) where {(created_by = (a .~ Normal(μ = μ, σ = σ)))})
    end
    invars = MacroTools.gensym_ids.(gensym.((:μ, :σ)))
    output = quote
        a = broadcast(μ, σ) do $(invars...)
            return GraphPPL.make_node!(
                __model__,
                __context__,
                Normal,
                GraphPPL.Broadcasted(:a),
                (μ = $(invars[1]), σ = $(invars[2]));
                __parent_options__ = GraphPPL.prepare_options(
                    __parent_options__,
                    $(GraphPPL.FactorNodeOptions((
                        created_by = :(a .~ Normal(μ = μ, σ = σ)),
                    ))),
                    __debug__,
                ),
                __debug__ = __debug__,
            )
        end
        a = GraphPPL.ResizableArray(a)
        __context__[:a] = a
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

    # Test 13: Test node creation with broadcasting call with mixed args and kwargs
    input = quote
        a .~ (
            some_node(
                a,
                b;
                μ = μ,
                σ = σ,
            ) where {(created_by = (a .~ some_node(a, b; μ = μ, σ = σ),))}
        )
    end
    invars = MacroTools.gensym_ids.(gensym.((:a, :b, :μ, :σ)))
    output = quote
        a = broadcast(a, b, μ, σ) do $(invars...)
            return GraphPPL.make_node!(
                __model__,
                __context__,
                some_node,
                GraphPPL.Broadcasted(:a),
                GraphPPL.MixedArguments(
                    [$(invars[1:2]...)],
                    (μ = $(invars[3]), σ = $(invars[4])),
                );
                __parent_options__ = GraphPPL.prepare_options(
                    __parent_options__,
                    $(GraphPPL.FactorNodeOptions((
                        created_by = :((a .~ some_node(a, b; μ = μ, σ = σ)),),
                    ))),
                    __debug__,
                ),
                __debug__ = __debug__,
            )
        end
        a = GraphPPL.ResizableArray(a)
        __context__[:a] = a
    end
    @test_expression_generating apply_pipeline(input, convert_tilde_expression) output

end

@testitem "options_vector_to_factoroptions" begin
    import GraphPPL: options_vector_to_named_tuple

    # Test 1: Test with empty input
    input = []
    output = nothing
    @test options_vector_to_named_tuple(input) == output

    # Test 2: Test with input with two clauses

    input = [:(anonymous = true), :(created_by = (x ~ Normal(Normal(0, 1), 0)))]
    output = (anonymous = true, created_by = :(x ~ Normal(Normal(0, 1), 0)))
    @test options_vector_to_named_tuple(input) == output

    # Test 3: Test with factorized input on rhs
    input = [:(q = q(y_mean)q(y_var)q(y))]
    output = (q = :(q(y_mean)q(y_var)q(y)),)
    @test options_vector_to_named_tuple(input) == output
end

@testitem "prepare_options" begin
    import GraphPPL: prepare_options, FactorNodeOptions

    # Test 1: Test if both parent options and node options are nothing
    parent_options = FactorNodeOptions()
    node_options = FactorNodeOptions()
    @test prepare_options(parent_options, node_options, true) == FactorNodeOptions()
    @test prepare_options(parent_options, node_options, false) == FactorNodeOptions()

    # Test 2: Test if parent options are nothing and node options have value
    parent_options = FactorNodeOptions()
    node_options = FactorNodeOptions((q = :(MeanField()),))
    @test prepare_options(parent_options, node_options, true) ==
          FactorNodeOptions((q = :(MeanField()),))
    @test prepare_options(parent_options, node_options, false) ==
          FactorNodeOptions((q = :(MeanField()),))

    # Test 3: Test if parent options have value and node options are nothing
    parent_options = FactorNodeOptions((prod_1 = (q = :(MeanField()),),))
    node_options = FactorNodeOptions()
    @test prepare_options(parent_options, node_options, true) ==
          FactorNodeOptions((parent_options = parent_options,),)
    @test prepare_options(parent_options, node_options, false) ==
          FactorNodeOptions((parent_options = parent_options,),)

    # Test 4: Test if parent options and node options have value
    parent_options = (prod_1 = (q = :(MeanField()),),)
    node_options = (q = :(MeanField()),)
    output = (prod_1 = (q = :(MeanField()),), q = :(MeanField()))
    @test prepare_options(parent_options, node_options, true) == output

    # Test 5: Test if parent options are nothing, node options have value and created_by clause exists
    parent_options = FactorNodeOptions()
    node_options =
        FactorNodeOptions((created_by = :(x ~ Normal(Normal(0, 1), 0)), q = :(MeanField())))
    @test prepare_options(parent_options, node_options, true) == node_options
    @test prepare_options(parent_options, node_options, false) ==
          FactorNodeOptions((q = :(MeanField()),))

    # Test 6: Test if parent options are nothing and node options only has created_by clause
    parent_options = FactorNodeOptions()
    node_options = FactorNodeOptions((created_by = :(x ~ Normal(Normal(0, 1), 0)),))
    @test prepare_options(parent_options, node_options, true) ==
          FactorNodeOptions((created_by = :(x ~ Normal(Normal(0, 1), 0)),))
    @test prepare_options(parent_options, node_options, false) == FactorNodeOptions()
end

@testitem "model_macro_interior" begin
    using LinearAlgebra
    using Distributions
    include("model_zoo.jl")
    using GraphPPL
    using Graphs
    using MetaGraphsNext
    import GraphPPL:
        model_macro_interior,
        create_model,
        getcontext,
        getorcreate!,
        make_node!,
        proxylabel,
        add_terminated_submodel!

    # Test 1: Test regular node creation input
    @model function test_model(μ, σ)
        x ~ sum(μ, σ)
    end
    __model__ = create_model()
    __context__ = getcontext(__model__)
    μ = getorcreate!(__model__, __context__, :μ, nothing)
    σ = getorcreate!(__model__, __context__, :σ, nothing)
    make_node!(
        __model__,
        __context__,
        test_model,
        proxylabel(:μ, nothing, μ),
        (σ = σ,);
        __debug__ = false,
    )
    @test nv(__model__) == 4 && ne(__model__) == 3

    # Test 2: Test regular node creation input with vector
    @model function test_model(μ, σ)
        local x
        for i = 1:10
            x[i] ~ sum(μ, σ)
        end
        y ~ x[1] + x[10]
    end

    __model__ = create_model()
    ctx = getcontext(__model__)
    μ = getorcreate!(__model__, ctx, :μ, nothing)
    σ = getorcreate!(__model__, ctx, :σ, nothing)
    make_node!(
        __model__,
        ctx,
        test_model,
        proxylabel(:μ, nothing, μ),
        (σ = σ,);
        __debug__ = false,
    )
    x = ctx[test_model, 1][:x]
    for i in x
        @test isa(i, GraphPPL.NodeLabel) && isa(__model__[i], GraphPPL.VariableNodeData)
    end
    @test nv(__model__) == 24


    # Test 3: Test regular node creation input with vector with illegal access
    @model function illegal_model(μ, σ)
        local x
        for i = 1:10
            x[i] ~ sum(μ, σ)
        end
        y ~ x[1] + x[10] + x[11]
    end
    __model__ = create_model()
    __context__ = getcontext(__model__)
    μ = getorcreate!(__model__, __context__, :μ, nothing)
    σ = getorcreate!(__model__, __context__, :σ, nothing)
    @test_throws BoundsError make_node!(
        __model__,
        __context__,
        illegal_model,
        proxylabel(:μ, nothing, μ),
        (σ = σ,);
        __debug__ = false,
    )

    # Test 4: Test Composite nodes with different number of interfaces
    @model function foo(x, y)
        x ~ y + 1
    end

    input_2 = quote
        function foo(x, y, z)
            x ~ y + z
        end
    end
    __model__ = create_model()
    __context__ = getcontext(__model__)
    x = getorcreate!(__model__, __context__, :x, nothing)
    y = getorcreate!(__model__, __context__, :y, nothing)
    make_node!(
        __model__,
        __context__,
        foo,
        proxylabel(:x, nothing, x),
        (y = y,);
        __debug__ = false,
    )
    @test nv(__model__) == 4 && ne(__model__) == 3

    # Test 5: Test deep anonymous deterministic function collapses to single node
    @model function model_with_deep_anonymous_call(x, y)
        z ~ Normal(x, Matrix{Float64}(Diagonal(ones(4))))
        y ~ Normal(z, 1)
    end
    __model__ = create_model()
    ctx = getcontext(__model__)
    x = getorcreate!(__model__, ctx, :x, nothing)
    y = getorcreate!(__model__, ctx, :y, nothing)
    x = make_node!(
        __model__,
        ctx,
        model_with_deep_anonymous_call,
        proxylabel(:x, nothing, x),
        (y = y,);
        __debug__ = false,
    )
    # Test that lhs of deterministic node call gets the corresponding value
    @test GraphPPL.value(__model__[label_for(__model__.graph, 8)]) ==
          Matrix{Float64}(Diagonal(ones(4)))
    GraphPPL.prune!(__model__)
    @test GraphPPL.nv(__model__) == 7 && GraphPPL.ne(__model__) == 6


    # Test add_terminated_submodel!
    __model__ = create_model()
    __context__ = getcontext(__model__)
    local y
    local x
    for i = 1:10
        y = getorcreate!(__model__, __context__, :y, i)
    end
    GraphPPL.add_terminated_submodel!(__model__, __context__, hgf, (y = y,), static(1))
    @test haskey(__context__, :ω_2) &&
          haskey(__context__, :x_1) &&
          haskey(__context__, :x_2) &&
          haskey(__context__, :x_3)

    # Test anonymous variable creation
    __model__ = create_model()
    __context__ = getcontext(__model__)
    local x_arr
    for i = 1:10
        x_arr = getorcreate!(__model__, __context__, :x, i)
    end
    x_arr = getorcreate!(__model__, __context__, :x, 1)
    y = getorcreate!(__model__, __context__, :y, nothing)
    make_node!(
        __model__,
        __context__,
        anonymous_in_loop,
        proxylabel(:y, nothing, y),
        (x = x_arr,),
    )
    @test nv(__model__) == 67
end
