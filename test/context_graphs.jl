module test_modular_graphs

using Test
using GraphPPL
using Graphs
using MetaGraphsNext

@testset "modular_graphs" begin
    @testset "create_new_model" begin
        import GraphPPL: create_model


        model = create_model()
        @test typeof(model) <: MetaGraph && nv(model) == 0 && ne(model) == 0

        model = create_model(:x, :y, :z)
        @test typeof(model) <: MetaGraph && nv(model) == 3 && ne(model) == 0

        @test_throws ErrorException create_model(:x, :x)
    end

    @testset "add_variable_node!" begin
        import GraphPPL: create_model, add_variable_node!

        model = create_model()
        add_variable_node!(model, model[], :x)
        @test nv(model) == 1 && haskey(model[], :x)

        add_variable_node!(model, model[], :y)
        @test nv(model) == 2 && haskey(model[], :x)

        @test_throws ErrorException add_variable_node!(model, model[], :x)
    end

    @testset "add_atomic_factor_node!" begin
        import GraphPPL: create_model, add_atomic_factor_node!

        model = create_model(:x)
        node_id = add_atomic_factor_node!(model, model[], sum)
        @test nv(model) == 2 && occursin("sum", String(label_for(model, 2)))
    end

    @testset "add_composite_factor_node!" begin
        import GraphPPL: create_model, add_composite_factor_node!, Context

        model = create_model(:x)
        child_context = Context(model[], sum)
        node_id = add_composite_factor_node!(model[], child_context, sum)
        @test nv(model) == 1 && typeof(model[][node_id]) == Context
    end

    @testset "ensure_markov_blanket_exists!(::Atomic)" begin
        import GraphPPL: create_model, ensure_markov_blanket_exists!, Atomic

        model = create_model()
        ensure_markov_blanket_exists!(model, model[]; in1 = :x, in2=:y)
        @test typeof(model) <: MetaGraph && nv(model) == 2 && ne(model) == 0

        model = create_model(:x, :y, :z)
        ensure_markov_blanket_exists!(model, model[]; in1 = :x, in2=:y)
        @test typeof(model) <: MetaGraph && nv(model) == 3 && ne(model) == 0

        model = create_model(:x, :y, :z)
        ensure_markov_blanket_exists!(model, model[]; in1 = :x, in2=:a)
        @test typeof(model) <: MetaGraph && nv(model) == 4 && ne(model) == 0
    end

    @testset "ensure_markov_blanket_exists!(::Composite)" begin
        import GraphPPL: create_model, ensure_markov_blanket_exists!, Composite, Context
        
        model = create_model()
        child_context = Context(model[], sum)
        ensure_markov_blanket_exists!(model, model[], child_context; in1 = :x, in2=:y, out=:z)
        @test nv(model) == 3 && haskey(model[], :x)

        model = create_model(:x)
        child_context = Context(model[], sum)
        ensure_markov_blanket_exists!(model, model[], child_context; in1 = :x, in2=:y, out=:z)
        @test nv(model) == 3 && haskey(model[], :x) && haskey(child_context, :in1)
    end

    @testset "make_node!(::Atomic)" begin
        import GraphPPL: create_model, make_node!, pprint, plot_graph

        model = create_model(:x, :y, :z)

        make_node!(model, sum; in1=:x, in2=:y, out=:w)
        @test nv(model) == 5 && ne(model) == 3 

        make_node!(model, sum; in1=:w, in2=:y, out=:z)
        @test nv(model) == 6 && ne(model) == 6

        plot_graph(model)

    end

    @testset "make_node!(::Composite)" begin
        import GraphPPL: create_model, make_node!, NodeType
        model = create_model(:x, :y, :z)
        make_node!(model, prod; in1=:x, in2=:y, out=:θ)
        make_node!(model, prod; in1=:θ, in2=:y, out=:z)

        @test nv(model) == 10 && ne(model) == 12
    end

    @testset "make_node!(::Equality)" begin
        import GraphPPL: create_model, make_node!, NodeType, equality_block
        model = create_model(:x, :y, :z, :a, :b, :c)
        make_node!(model, equality_block; in1=:x, in2=:y, in3=:z, in4=:a, in5=:b, in6=:c)

        @test nv(model) == 13 && ne(model) == 12

        model = create_model(:x, :y, :z)
        make_node!(model, equality_block; in1=:x, in2=:y, in3=:z)
 
        @test nv(model) == 4 && ne(model) == 3
    end

    @testset "terminate_node!(::Equality)" begin
        import GraphPPL: create_model, make_node!, NodeType, equality_block, terminate_at_neighbors!
        model = create_model(:x)

        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)

        terminate_at_neighbors!(model, 1)

        @test nv(model) == 6 && ne(model) == 3

    end

    @testset "construct_equality_block!(::Equality)" begin
        import GraphPPL: create_model, make_node!, NodeType, equality_block, terminate_at_neighbors!
        model = create_model(:x)
        
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)

        interfaces = terminate_at_neighbors!(model, 1)
        make_node!(model, model[], equality_block; interfaces...)

        @test nv(model) == 7 && ne(model) == 6

        model = create_model(:x)
        
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)

        interfaces = terminate_at_neighbors!(model, 1)
        make_node!(model, model[], equality_block; interfaces...)

        @test nv(model) == 11 && ne(model) == 10

    end

    @testset "convert_to_ffg!(::Equality)" begin
        import GraphPPL: create_model, make_node!, NodeType, equality_block, convert_to_ffg, plot_graph
        model = create_model(:x)
        
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)

        model = convert_to_ffg(model)

        @test nv(model) == 4 && ne(model) == 3

        model = create_model(:x)
        
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)
        make_node!(model,sum; in1=:x)

        model = convert_to_ffg(model)


        @test nv(model) == 6 && ne(model) == 5

    end
end

end