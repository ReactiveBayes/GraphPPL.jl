module test_modular_graphs

using Test
using GraphPPL
using Graphs
using MetaGraphsNext
using TestSetExtensions

@testset "graph_engine" begin

    @testset "model constructor" begin
        import GraphPPL: Model, NodeLabel, NodeData, EdgeData, Context

        g = MetaGraph(
            Graph(),
            Label = NodeLabel,
            VertexData = NodeData,
            graph_data = Context(),
            EdgeData = Symbol,
        )
        @test typeof(Model(g)) == Model

        @test_throws MethodError Model()
    end

    @testset "setindex!(::Model, ::NodeData, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, NodeData

        model = create_model()
        model[NodeLabel(:μ, 1)] = NodeData(true, :μ)
        @test GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        @test_throws MethodError model[0] = 1

        @test_throws MethodError model["string"] = NodeData(false, "string")
        model[NodeLabel(:x, 2)] = NodeData(true, :x)
        @test GraphPPL.nv(model) == 2 && GraphPPL.ne(model) == 0
    end

    @testset "setindex!(::Model, ::EdgeData, ::NodeLabel, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, NodeData, EdgeLabel

        model = create_model()
        μ = NodeLabel(:μ, 1)
        x = NodeLabel(:x, 2)
        model[μ] = NodeData(true, :μ)
        model[x] = NodeData(true, :x)
        model[μ, x] = EdgeLabel(:interface)
        @test GraphPPL.ne(model) == 1

        @test_throws MethodError model[0, 1] = 1

        @test_throws KeyError model[μ, NodeLabel(:x, 100)] = EdgeLabel(:if)
    end

    @testset "getindex(::Model, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, NodeData

        model = create_model(:x)
        @test model[NodeLabel(:x, 1)] == NodeData(true, :x)
        @test_throws KeyError model[NodeLabel(:x, 10)]
        @test_throws MethodError model[0]

        @test_throws KeyError model[NodeLabel(:x, 2)]
    end

    @testset "increase_count(::Model)" begin
        import GraphPPL: create_model, increase_count
        model = create_model()

        increase_count(model)

        @test model.counter == 1
        increase_count(model)
        @test model.counter == 2
    end

    @testset "nv_ne(::Model)" begin
        import GraphPPL: create_model, nv, ne, NodeData, NodeLabel, EdgeLabel

        model = create_model()
        @test nv(model) == 0
        @test ne(model) == 0

        model[NodeLabel(:a, 1)] = NodeData(true, :a)
        model[NodeLabel(:b, 2)] = NodeData(false, :b)
        @test nv(model) == 2
        @test ne(model) == 0

        model[NodeLabel(:a, 1), NodeLabel(:b, 2)] = EdgeLabel(:edge)
        @test nv(model) == 2
        @test ne(model) == 1
    end

    @testset "gensym(::Model, ::Symbol)" begin
        import GraphPPL: create_model, gensym, NodeLabel

        model = create_model()
        first_sym = gensym(model, :x)
        @test typeof(first_sym) == NodeLabel

        second_sym = gensym(model, :x)
        @test first_sym != second_sym && first_sym.name == second_sym.name

        id = gensym(model, :c)
        @test id.name == :c && id.index == 3


        id = gensym(model, "d")
        @test id.name == :d && id.index == 4

    end

    @testset "to_symbol(::NodeLabel)" begin
        import GraphPPL: to_symbol, NodeLabel
        @test to_symbol(NodeLabel(:a, 1)) == :a_1
        @test to_symbol(NodeLabel(:b, 2)) == :b_2
    end

    @testset "name" begin
        import GraphPPL: name
        @test name(+) == "+"
        @test name(-) == "-"
        @test name(sin) == "sin"
        @test name(cos) == "cos"
        @test name(exp) == "exp"
    end

    @testset "Context" begin
        import GraphPPL: Context

        ctx1 = Context()
        @test typeof(ctx1) == Context
        @test ctx1.prefix == ""
        @test length(ctx1.contents) == 0

        ctx2 = Context("test_")
        @test typeof(ctx2) == Context
        @test ctx2.prefix == "test_"
        @test length(ctx2.contents) == 0

        ctx3 = Context(ctx2, "model")
        @test typeof(ctx3) == Context
        @test ctx3.prefix == "test_model_"
        @test length(ctx3.contents) == 0

        @test_throws MethodError Context(ctx2, :my_model)

        ctx5 = Context(ctx2, "layer")
        @test typeof(ctx5) == Context
        @test ctx5.prefix == "test_layer_"
        @test length(ctx5.contents) == 0
    end

    @testset "haskey(::Context)" begin
        import GraphPPL: Context

        ctx = Context()
        xlab = NodeLabel(:x, 1)
        @test !haskey(ctx, :x)
        ctx.contents[:x] = xlab
        @test haskey(ctx, :x)
    end

    @testset "getindex(::Context, ::Symbol)" begin
        import GraphPPL: Context

        ctx = Context()
        xlab = NodeLabel(:x, 1)
        @test_throws KeyError getindex(ctx, :x)
        ctx.contents[:x] = xlab
        @test getindex(ctx, :x) == xlab
    end

    @testset "context(::Model)" begin
        import GraphPPL: Context, context, create_model, add_variable_node!

        model = create_model()
        @test context(model) == model.graph[]
        add_variable_node!(model, context(model), :x)
        @test context(model)[:x] == model.graph[][:x]
    end


    @testset "NodeType" begin
        import GraphPPL: NodeType, Composite, Atomic
        @test NodeType(Composite) == Atomic()
        @test NodeType(Atomic) == Atomic()
        @test NodeType(abs) == Atomic()
    end

    @testset "put!(::Context, ::Symbol, ::Union{NodeLabel, Context})" begin
        import GraphPPL: put!, create_model, NodeLabel
        model = create_model()
        context = model[]

        # test putting a NodeLabel
        label = NodeLabel(:a, 1)
        label = GraphPPL.put!(context, label.name, label)
        @test context[label.name] == label

        # test putting a Context
        subcontext = Context()
        GraphPPL.put!(context, :subcontext, subcontext)
        @test context[:subcontext] == subcontext

        # test putting duplicate keys
        label2 = NodeLabel(:a, 2)
        GraphPPL.put!(context, label2, subcontext)
        @test_throws ErrorException GraphPPL.put!(context, :a, label2)
    end


    @testset "create_new_model(interfaces)" begin
        import GraphPPL: create_model, Model, plot_graph


        model = create_model()
        @test typeof(model) <: Model && nv(model) == 0 && ne(model) == 0

        model = create_model(:x, :y, :z)
        @test typeof(model) <: Model && nv(model) == 3 && ne(model) == 0

        @test_throws ErrorException create_model(:x, :x)
    end

    @testset "copy_markov_blanket_to_child_context" begin
        import GraphPPL:
            create_model,
            copy_markov_blanket_to_child_context,
            Context,
            pprint,
            getorcreate!

        model = create_model(:x, :y, :z)
        child_context = Context(context(model), "child")
        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        copy_markov_blanket_to_child_context(child_context, (in1 = x, in2 = y, out = z))
        @test child_context[:in1].name == :x
    end

    @testset "getorcreate!" begin
        import GraphPPL: create_model, getorcreate!, Context

        model = create_model()
        getorcreate!(model, :x)
        @test nv(model) == 1

        x = getorcreate!(model, :x)
        @test nv(model) == 1

        y = getorcreate!(model, :y)
        @test nv(model) == 2

        (in1, in2) = getorcreate!(model, [:in_1, :in2])
        @test nv(model) == 4

        z = getorcreate!(model, 1)
        @test nv(model) == 4


        child_context = Context(context(model), "child")
        copy_markov_blanket_to_child_context(child_context, (in = x, out = y))

        @test getorcreate!(model, child_context, :in) == getorcreate!(model, :x)
    end

    @testset "add_variable_node!" begin
        import GraphPPL: create_model, add_variable_node!, context

        model = create_model()
        node_id = add_variable_node!(model, context(model), :x)
        @test nv(model) == 1 && haskey(model[], :x) && context(model)[:x] == node_id

        add_variable_node!(model, context(model), :y)
        @test nv(model) == 2 && haskey(model[], :x)

        @test_throws ErrorException add_variable_node!(model, context(model), :x)

        @test_throws MethodError add_variable_node!(model, context(model), 1)

    end

    @testset "add_atomic_factor_node!" begin
        import GraphPPL: create_model, add_atomic_factor_node!

        model = create_model(:x)
        node_id = add_atomic_factor_node!(model, model[], sum)

        @test nv(model) == 2 && occursin("sum", String(label_for(model.graph, 2).name))
        node_id = add_atomic_factor_node!(model, model[], sum)

        @test nv(model) == 3 && occursin("sum", String(label_for(model.graph, 3).name))

        @test_throws MethodError add_atomic_factor_node!(model, model[], 1)
    end

    @testset "add_edge!(::Model, ::NodeLabel, ::NodeLabel, ::Symbol)" begin
        import GraphPPL:
            create_model, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!

        model = create_model()
        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)
        add_edge!(model, x, y, :interface)


        @test ne(model) == 1

        @test_throws MethodError add_edge!(model, x, y, 123)

        @test_throws KeyError add_edge!(
            model,
            gensym(model, :factor_node),
            gensym(model, :factor_node2),
            :interface,
        )


    end

    @testset "add_edge!(::Model, ::NodeLabel, ::NodeLabel, ::Symbol)" begin
        import GraphPPL:
            create_model, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!
        model = create_model()
        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)

        variable_nodes = [getorcreate!(model, i) for i in [:a, :b, :c]]
        add_edge!(model, y, variable_nodes, :interface)

        @test ne(model) == 3
    end


    @testset "make_node!(::Atomic)" begin
        import GraphPPL: create_model, make_node!, pprint, plot_graph, getorcreate!

        model = create_model(:x, :y, :z)

        θ = getorcreate!(model, :x)
        τ = getorcreate!(model, :y)
        μ = getorcreate!(model, :w)
        make_node!(model, sum, (in1 = θ, in2 = τ, out = μ))
        @test nv(model) == 5 && ne(model) == 3



        w = getorcreate!(model, :w)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        make_node!(model, sum, (in1 = w, in2 = y, out = z))
        @test nv(model) == 6 && ne(model) == 6



        model = create_model(:x, :y, :z)
        f = sum
        θ = getorcreate!(model, :x)
        τ = getorcreate!(model, :y)
        μ = getorcreate!(model, :w)
        make_node!(model, f, (in1 = θ, in2 = τ, out = μ))
        @test nv(model) == 5 && ne(model) == 3


    end

    @testset "make_node!(::Equality)" begin
        import GraphPPL: create_model, make_node!, NodeType, equality_block, plot_graph
        model = create_model(:x, :y, :z, :a, :b, :c)


        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        a = getorcreate!(model, :a)
        b = getorcreate!(model, :b)
        c = getorcreate!(model, :c)
        make_node!(
            model,
            equality_block,
            (in1 = x, in2 = y, in3 = z, in4 = a, in5 = b, in6 = c),
        )

        @test nv(model) == 13 && ne(model) == 12

        model = create_model(:x, :y, :z)
        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        make_node!(model, equality_block, (in1 = x, in2 = y, in3 = z))

        @test nv(model) == 4 && ne(model) == 3
    end

    @testset "terminate_node!(::Equality)" begin
        import GraphPPL:
            create_model, make_node!, NodeType, equality_block, terminate_at_neighbors!
        model = create_model(:x)
        x = getorcreate!(model, :x)
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        terminate_at_neighbors!(model, 1)

        @test nv(model) == 6 && ne(model) == 3

    end

    @testset "construct_equality_block!(::Equality)" begin
        import GraphPPL:
            create_model, make_node!, NodeType, equality_block, terminate_at_neighbors!
        model = create_model(:x)

        x = getorcreate!(model, :x)

        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        interfaces = terminate_at_neighbors!(model, 1)
        make_node!(model, model[], equality_block, interfaces)

        @test nv(model) == 7 && ne(model) == 6

        model = create_model(:x)

        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        interfaces = terminate_at_neighbors!(model, 1)
        make_node!(model, model[], equality_block, interfaces)

        @test nv(model) == 11 && ne(model) == 10

    end

    @testset "convert_to_ffg!(::Equality)" begin
        import GraphPPL:
            create_model, make_node!, NodeType, equality_block, convert_to_ffg, plot_graph
        model = create_model(:x)
        x = getorcreate!(model, :x)
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        model = convert_to_ffg(model)

        @test nv(model) == 4 && ne(model) == 3

        model = create_model(:x)
        x = getorcreate!(model, :x)
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        model = convert_to_ffg(model)



        @test nv(model) == 6 && ne(model) == 5

    end



end

end
