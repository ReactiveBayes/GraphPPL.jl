@testitem "Multi-output submodel: two outputs" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function two_output_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    @model function main_multi_two(x)
        (a, b) ~ two_output_sub(x = x)
        y ~ Normal(a, b)
    end

    model = create_model(main_multi_two()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end

    # The submodel has 1 Normal inside, plus the outer model has 1 Normal => 3 total Normal nodes
    # (two_output_sub creates 2 Normals, main creates 1)
    @test length(collect(filter(as_node(Normal), model))) === 3
    @test length(collect(filter(as_variable(:a), model))) === 1
    @test length(collect(filter(as_variable(:b), model))) === 1
    @test length(collect(filter(as_variable(:x), model))) === 1
end

@testitem "Multi-output submodel: three outputs" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function three_output_sub(a, b, c, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
        c ~ Normal(b, 1)
    end

    @model function main_multi_three(x)
        (a, b, c) ~ three_output_sub(x = x)
        y ~ Normal(a + b, c)
    end

    model = create_model(main_multi_three()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end

    # three_output_sub: 3 Normals, main: 1 Normal => 4 Normals total
    @test length(collect(filter(as_node(Normal), model))) === 4
    @test length(collect(filter(as_variable(:a), model))) === 1
    @test length(collect(filter(as_variable(:b), model))) === 1
    @test length(collect(filter(as_variable(:c), model))) === 1
end

@testitem "Multi-output submodel: wrong number of LHS variables" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function two_iface_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    # Only one missing interface (a) but providing two on LHS
    @model function main_mismatch(x)
        b ~ Normal(0, 1)
        (p, q) ~ two_iface_sub(x = x, b = b)
    end

    @test_throws "no method matching make_node!" create_model(main_mismatch()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end
end

@testitem "Multi-output submodel in a loop" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions, VariableKindData

    include("testutils.jl")

    @model function pair_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    @model function main_loop_multi(x, n)
        for i in 1:n
            (a[i], b[i]) ~ pair_sub(x = x)
        end
    end

    model = create_model(main_loop_multi(n = 3)) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end

    # Each iteration creates 2 Normals -> 3 * 2 = 6
    @test length(collect(filter(as_node(Normal), model))) === 6
    @test length(collect(filter(as_variable(:a), model))) === 3
    @test length(collect(filter(as_variable(:b), model))) === 3
end

@testitem "Multi-output submodel: named LHS basic" begin
    using Distributions
    import GraphPPL: create_model, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function named_two_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    @model function main_named_two(x)
        (a = out_a, b = out_b) ~ named_two_sub(x = x)
        y ~ Normal(out_a, out_b)
    end

    model = create_model(main_named_two()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end

    @test length(collect(filter(as_node(Normal), model))) === 3
    @test length(collect(filter(as_variable(:out_a), model))) === 1
    @test length(collect(filter(as_variable(:out_b), model))) === 1
    @test length(collect(filter(as_variable(:x), model))) === 1
end

@testitem "Multi-output submodel: named LHS order-invariant" begin
    using Distributions
    import GraphPPL: create_model, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function ordered_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    # Provide b before a on the LHS — must still bind correctly by name
    @model function main_swapped(x)
        (b = out_b, a = out_a) ~ ordered_sub(x = x)
        y ~ Normal(out_a, out_b)
    end

    model = create_model(main_swapped()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end

    @test length(collect(filter(as_node(Normal), model))) === 3
    @test length(collect(filter(as_variable(:out_a), model))) === 1
    @test length(collect(filter(as_variable(:out_b), model))) === 1
end

@testitem "Multi-output submodel: named LHS in a loop" begin
    using Distributions
    import GraphPPL: create_model, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function loop_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    @model function main_named_loop(x, n)
        for i in 1:n
            (a = out_a[i], b = out_b[i]) ~ loop_sub(x = x)
        end
    end

    model = create_model(main_named_loop(n = 3)) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end

    @test length(collect(filter(as_node(Normal), model))) === 6
    @test length(collect(filter(as_variable(:out_a), model))) === 3
    @test length(collect(filter(as_variable(:out_b), model))) === 3
end

@testitem "Multi-output submodel: named LHS invalid interface name" begin
    using Distributions
    import GraphPPL: create_model, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function valid_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    @model function main_bad_name(x)
        (z = out_z, b = out_b) ~ valid_sub(x = x)
    end

    @test_throws "does not exist in" create_model(main_bad_name()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end
end

@testitem "Multi-output submodel: named LHS conflicts with RHS" begin
    using Distributions
    import GraphPPL: create_model, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function conflict_sub(a, b, x)
        a ~ Normal(x, 1)
        b ~ Normal(a, 1)
    end

    # 'b' appears as a key on both LHS (meaning "bind out_b to interface b") and as a kwarg on RHS — must error
    @model function main_conflict(some_var)
        (b = out_b, a = out_a) ~ conflict_sub(b = some_var)
    end

    @test_throws "is specified on both LHS and RHS" create_model(main_conflict()) do model, ctx
        some_var = datalabel(model, ctx, NodeCreationOptions(kind = :data), :some_var, 1.0)
        return (some_var = some_var,)
    end
end

@testitem "Multi-output: is_named_tuple_lhs helper" begin
    import GraphPPL: is_named_tuple_lhs

    @test is_named_tuple_lhs(:(a)) === false
    @test is_named_tuple_lhs(:((a, b))) === false
    @test is_named_tuple_lhs(:((a = x, b = y))) === true
    @test is_named_tuple_lhs(:((a = x,))) === true
    # Mixed tuple (one named, one positional) is not pure named
    @test is_named_tuple_lhs(Expr(:tuple, Expr(:(=), :a, :x), :b)) === false
end

@testitem "Multi-output: add_get_or_create_expression pipeline step" begin
    import GraphPPL: apply_pipeline, add_get_or_create_expression

    include("testutils.jl")

    # Positional tuple LHS produces get_or_create blocks for each element
    input_positional = quote
        (a, b) ~ sub(x = x) where {created_by = ((a, b) ~ sub(x = x))}
    end
    result = apply_pipeline(input_positional, add_get_or_create_expression)
    @test result isa Expr

    # Named tuple LHS produces get_or_create blocks for the outer (value) variables
    input_named = quote
        (a = m_a, b = m_b) ~ sub(x = x) where {created_by = ((a = m_a, b = m_b) ~ sub(x = x))}
    end
    result = apply_pipeline(input_named, add_get_or_create_expression)
    @test result isa Expr
end

@testitem "Multi-output: convert_tilde_expression pipeline step" begin
    import GraphPPL: apply_pipeline, convert_tilde_expression

    include("testutils.jl")

    # Positional tuple LHS emits a make_node! call
    input_positional = quote
        (a, b) ~ sub(x = x) where {created_by = ((a, b) ~ sub(x = x))}
    end
    result_positional = apply_pipeline(input_positional, convert_tilde_expression)
    @test result_positional isa Expr
    @test occursin("make_node!", string(result_positional))

    # Named tuple LHS also emits a make_node! call
    input_named = quote
        (a = m_a, b = m_b) ~ sub(x = x) where {created_by = ((a = m_a, b = m_b) ~ sub(x = x))}
    end
    result_named = apply_pipeline(input_named, convert_tilde_expression)
    @test result_named isa Expr
    @test occursin("make_node!", string(result_named))
end
