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
    @test length(collect(filter(as_variable(:a), model))) >= 1
    @test length(collect(filter(as_variable(:b), model))) >= 1
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
    @test length(collect(filter(as_variable(:a), model))) >= 1
    @test length(collect(filter(as_variable(:b), model))) >= 1
    @test length(collect(filter(as_variable(:c), model))) >= 1
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

    @test_throws Exception create_model(main_mismatch()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end
end

@testitem "Zero-output submodel: all interfaces provided" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function closed_sub(x, y)
        z ~ Normal(x, 1)
        y ~ Normal(z, 1)
    end

    @model function main_zero_output(x, y)
        ~ closed_sub(x = x, y = y)
    end

    model = create_model(main_zero_output()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        y = datalabel(model, ctx, NodeCreationOptions(kind = :data), :y, 2.0)
        return (x = x, y = y)
    end

    @test length(collect(filter(as_node(Normal), model))) === 2
    @test length(collect(filter(as_variable(:x), model))) === 1
    @test length(collect(filter(as_variable(:y), model))) === 1
end

@testitem "Zero-output submodel: missing interface should error" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function needs_output_sub(a, x)
        a ~ Normal(x, 1)
    end

    # Only providing x, but 'a' is still missing -> should error
    @model function main_zero_missing(x)
        ~ needs_output_sub(x = x)
    end

    @test_throws Exception create_model(main_zero_missing()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 1.0)
        return (x = x,)
    end
end

@testitem "Zero-output submodel: with constants inside" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions

    include("testutils.jl")

    @model function fully_closed_sub(x)
        y ~ Normal(x, 1)
        z ~ Normal(y, 2)
    end

    @model function main_fully_closed(x)
        ~ fully_closed_sub(x = x)
    end

    model = create_model(main_fully_closed()) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = :data), :x, 5.0)
        return (x = x,)
    end

    @test length(collect(filter(as_node(Normal), model))) === 2
    @test length(collect(filter(as_variable(:x), model))) === 1
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

@testitem "Zero-output submodel in a loop" begin
    using Distributions
    import GraphPPL: create_model, getorcreate!, datalabel, NodeCreationOptions, VariableKindData

    include("testutils.jl")

    @model function observe_sub(x, y)
        y ~ Normal(x, 1)
    end

    @model function main_loop_zero(x, y, n)
        for i in 1:n
            ~ observe_sub(x = x[i], y = y[i])
        end
    end

    model = create_model(main_loop_zero(n = 4)) do model, ctx
        x = datalabel(model, ctx, NodeCreationOptions(kind = VariableKindData), :x)
        y = datalabel(model, ctx, NodeCreationOptions(kind = VariableKindData), :y)
        return (x = x, y = y)
    end

    @test length(collect(filter(as_node(Normal), model))) === 4
    @test length(collect(filter(as_variable(:x), model))) === 4
    @test length(collect(filter(as_variable(:y), model))) === 4
end

@testitem "convert_zero_output_tilde pipeline step" begin
    import GraphPPL: apply_pipeline, convert_zero_output_tilde

    include("testutils.jl")

    # Test that unary ~ is converted to binary with __nothing__
    input = Expr(:call, :~, :(my_submodel(x = 1, y = 2)))
    output = apply_pipeline(input, convert_zero_output_tilde)
    @test output.head == :call
    @test output.args[1] == :~
    @test output.args[2] == :__nothing__
    @test output.args[3] == :(my_submodel(x = 1, y = 2))

    # Test that binary ~ is left unchanged
    input2 = :(x ~ Normal(0, 1))
    output2 = apply_pipeline(input2, convert_zero_output_tilde)
    @test output2 == input2
end
