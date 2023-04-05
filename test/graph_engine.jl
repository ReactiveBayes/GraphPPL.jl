module test_modular_graphs

using Test
using GraphPPL
using Graphs
using MetaGraphsNext
using TestSetExtensions

@testset "graph_engine" begin
    @testset "model constructor" begin
        import GraphPPL: Model, NodeLabel, NodeData, Context

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
        model[NodeLabel(:μ, 1, 1, 0)] = NodeData(true, :μ)
        @test GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        @test_throws MethodError model[0] = 1

        @test_throws MethodError model["string"] = NodeData(false, "string")
        model[NodeLabel(:x, 2, 1, 0)] = NodeData(true, :x)
        @test GraphPPL.nv(model) == 2 && GraphPPL.ne(model) == 0
    end

    @testset "setindex!(::Model, ::EdgeLabel, ::NodeLabel, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, NodeData, EdgeLabel

        model = create_model()
        μ = NodeLabel(:μ, 1, 1, 0)
        x = NodeLabel(:x, 2, 1, 0)
        model[μ] = NodeData(true, :μ)
        model[x] = NodeData(true, :x)
        model[μ, x] = EdgeLabel(:interface)
        @test GraphPPL.ne(model) == 1

        @test_throws MethodError model[0, 1] = 1

        @test_throws KeyError model[μ, NodeLabel(:x, 1, 100, 0)] = EdgeLabel(:if)
    end

    @testset "getindex(::Model, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, NodeData

        model = create_model()
        label = NodeLabel(:x, 1, 1, 0)
        model[label] = NodeData(true, :x)
        @test model[label] == NodeData(true, :x)
        @test_throws KeyError model[NodeLabel(:x, 1, 10, 0)]
        @test_throws MethodError model[0]
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

        model[NodeLabel(:a, 1, 1, 0)] = NodeData(true, :a)
        model[NodeLabel(:b, 2, 1, 0)] = NodeData(false, :b)
        @test nv(model) == 2
        @test ne(model) == 0

        model[NodeLabel(:a, 1, 1, 0), NodeLabel(:b, 2, 1, 0)] = EdgeLabel(:edge)
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
        @test id.name == :d && id.index == 4 && id.variable_type == 1


        id = gensym(model, :d, 3)
        @test id.name == :d && id.index == 5 && id.variable_type == 2

        id = gensym(model, :d, (2, 1))
        @test id.name == :d && id.index == 6 && id.variable_type == 3

        id = gensym(model, "d", (2, 1))
        @test id.name == :d && id.index == 7 && id.variable_type == 3

        id = gensym(model, "d", 2)
        @test id.name == :d && id.index == 8 && id.variable_type == 2

        @test_throws ArgumentError gensym(model, :d, (2, "a"))

    end


    @testset "to_symbol(::NodeLabel)" begin
        import GraphPPL: to_symbol, NodeLabel
        @test to_symbol(NodeLabel(:a, 1, 1, 0)) == :a_1
        @test to_symbol(NodeLabel(:b, 2, 1, 0)) == :b_2
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
        @test length(ctx1.individual_variables) == 0

        ctx2 = Context("test_")
        @test typeof(ctx2) == Context
        @test ctx2.prefix == "test_"
        @test length(ctx2.individual_variables) == 0

        ctx3 = Context(ctx2, "model")
        @test typeof(ctx3) == Context
        @test ctx3.prefix == "test_model_"
        @test length(ctx3.individual_variables) == 0

        @test_throws MethodError Context(ctx2, :my_model)

        ctx5 = Context(ctx2, "layer")
        @test typeof(ctx5) == Context
        @test ctx5.prefix == "test_layer_"
        @test length(ctx5.individual_variables) == 0
    end

    @testset "haskey(::Context)" begin
        import GraphPPL: Context

        ctx = Context()
        xlab = NodeLabel(:x, 1, 1, 0)
        @test !haskey(ctx.individual_variables, :x)
        ctx.individual_variables[:x] = xlab
        @test haskey(ctx.individual_variables, :x)
        @test !haskey(ctx.vector_variables, :y)
    end

    @testset "getindex(::Context, ::Symbol)" begin
        import GraphPPL: Context

        ctx = Context()
        xlab = NodeLabel(:x, 1, 1, 0)
        @test_throws KeyError ctx[:x]
        ctx.individual_variables[:x] = xlab
        @test ctx[:x] == xlab
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

    @testset "create_new_model()" begin
        import GraphPPL: create_model, Model, plot_graph


        model = create_model()
        @test typeof(model) <: Model && nv(model) == 0 && ne(model) == 0

        @test_throws MethodError create_model(:x, :y, :z)
    end

    @testset "copy_markov_blanket_to_child_context" begin
        import GraphPPL:
            create_model,
            copy_markov_blanket_to_child_context,
            Context,
            pprint,
            getorcreate!

        model = create_model()
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

        @test_throws MethodError getorcreate!(model, 1)

        child_context = Context(context(model), "child")
        copy_markov_blanket_to_child_context(child_context, (in = x, out = y))

        @test getorcreate!(model, child_context, :in) == getorcreate!(model, :x)

        model = create_model()
        v1 = getorcreate!(model, context(model), :v, 1)
        @test nv(model) == 1
        @test context(model)[:v][1] == v1

        mv = getorcreate!(model, context(model), :mv, (2, 3))
        @test haskey(context(model).tensor_variables, :mv)
        @test nv(model) == 2
        @test context(model)[:mv][2, 3] == mv

        @test_throws ErrorException getorcreate!(model, context(model), :mv)

        mv = getorcreate!(model, context(model), :mv, (2, 3))
        @test nv(model) == 2
        @test context(model)[:mv][2, 3] == mv

        mv = getorcreate!(model, context(model), :mv, (2, 4))
        @test nv(model) == 3
        @test context(model)[:mv][2, 4] == mv



    end


    @testset "add_variable_node!" begin
        import GraphPPL: create_model, add_variable_node!, context

        #simple add variable to model
        model = create_model()
        ctx = context(model)
        node_id = add_variable_node!(model, ctx, :x)
        @test nv(model) == 1 &&
              haskey(ctx.individual_variables, :x) &&
              ctx.individual_variables[:x] == node_id

        #add second variable to model
        add_variable_node!(model, ctx, :y)
        @test nv(model) == 2 && haskey(ctx, :y)

        #check that adding an integer variable throws a MethodError
        @test_throws MethodError add_variable_node!(model, ctx, 1)

        #add a vector variable to the model
        model = create_model()
        ctx = context(model)
        node_id = add_variable_node!(model, ctx, :x, 2)
        @test nv(model) == 1 &&
              haskey(ctx, :x) &&
              ctx[:x][2] == node_id &&
              length(ctx[:x]) == 2

        #add a second vector variable to the model
        node_id = add_variable_node!(model, ctx, :x, 1)
        @test nv(model) == 2 &&
              haskey(ctx, :x) &&
              ctx[:x][1] == node_id &&
              length(ctx[:x]) == 2

        #add a tensor variable to the model
        model = create_model()
        ctx = context(model)
        node_id = add_variable_node!(model, ctx, :x, (2, 3))
        @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2, 3] == node_id

        #add a second tensor variable to the model
        node_id = add_variable_node!(model, ctx, :x, (2, 4))
        @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][2, 4] == node_id

        # Attempt to add a variable with an existing index
        model = create_model()
        ctx = context(model)
        node_id = add_variable_node!(model, ctx, :y, 1)
        node_id = add_variable_node!(model, ctx, :y, 1)


        # Add a variable with a non-integer index
        @test_throws ArgumentError add_variable_node!(model, ctx, :z, (1, "a"))

        # Add a variable with a negative index
        @test_throws BoundsError add_variable_node!(model, ctx, :w, -1)

    end

    @testset "add_atomic_factor_node!" begin
        import GraphPPL: create_model, add_atomic_factor_node!, getorcreate!

        model = create_model()
        getorcreate!(model, :x)
        node_id = add_atomic_factor_node!(model, model[], sum)

        @test nv(model) == 2 && occursin("sum", String(label_for(model.graph, 2).name))
        node_id = add_atomic_factor_node!(model, model[], sum)

        @test nv(model) == 3 && occursin("sum", String(label_for(model.graph, 3).name))

        @test_throws MethodError add_atomic_factor_node!(model, model[], 1)
    end

    @testset "add_composite_factor_node!" begin
        import GraphPPL: create_model, add_composite_factor_node!, context

        # Add a composite factor node to the model
        model = create_model()
        parent_ctx = context(model)
        child_ctx = context(model)
        add_variable_node!(model, child_ctx, :x)
        add_variable_node!(model, child_ctx, :y)
        node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :f)
        @test nv(model) == 2 &&
              haskey(parent_ctx.factor_nodes, node_id) &&
              parent_ctx.factor_nodes[node_id] === child_ctx &&
              length(child_ctx.individual_variables) == 2


        # Add a composite factor node with a different name
        node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :g)
        @test nv(model) == 2 &&
              haskey(parent_ctx.factor_nodes, node_id) &&
              parent_ctx.factor_nodes[node_id] === child_ctx &&
              length(child_ctx.individual_variables) == 2

        # Add a composite factor node with an empty child context
        empty_ctx = Context()
        node_id = add_composite_factor_node!(model, parent_ctx, empty_ctx, :h)
        @test nv(model) == 2 &&
              haskey(parent_ctx.factor_nodes, node_id) &&
              parent_ctx.factor_nodes[node_id] === empty_ctx &&
              length(empty_ctx.individual_variables) == 0
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

        model = create_model()

        θ = getorcreate!(model, :x)
        τ = getorcreate!(model, :y)
        μ = getorcreate!(model, :w)
        make_node!(model, sum, (in1 = θ, in2 = τ, out = μ))
        @test nv(model) == 4 && ne(model) == 3



        w = getorcreate!(model, :w)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        make_node!(model, sum, (in1 = w, in2 = y, out = z))
        @test nv(model) == 6 && ne(model) == 6



        model = create_model()
        f = sum
        θ = getorcreate!(model, :x)
        τ = getorcreate!(model, :y)
        μ = getorcreate!(model, :w)
        make_node!(model, f, (in1 = θ, in2 = τ, out = μ))
        @test nv(model) == 4 && ne(model) == 3

        model = create_model()
        make_node!(model, sum, NamedTuple())
        @test nv(model) == 1

        #Test nested model
        model = create_model()
        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        make_node!(model, sum, (inputs = (in1 = x, in2 = y), output = z))
        @test nv(model) == 4 && ne(model) == 3


    end

    @testset "make_node!(::Equality)" begin
        import GraphPPL: create_model, make_node!, NodeType, equality_block, plot_graph
        model = create_model()


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

        model = create_model()
        x = getorcreate!(model, :x)
        y = getorcreate!(model, :y)
        z = getorcreate!(model, :z)
        make_node!(model, equality_block, (in1 = x, in2 = y, in3 = z))

        @test nv(model) == 4 && ne(model) == 3
    end

    @testset "terminate_node!(::Equality)" begin
        import GraphPPL:
            create_model, make_node!, NodeType, equality_block, terminate_at_neighbors!
        model = create_model()
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
        model = create_model()

        x = getorcreate!(model, :x)

        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        interfaces = terminate_at_neighbors!(model, 1)
        make_node!(model, model[], equality_block, interfaces)

        @test nv(model) == 7 && ne(model) == 6

        model = create_model()

        x = getorcreate!(model, :x)

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
        model = create_model()
        x = getorcreate!(model, :x)
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))
        make_node!(model, sum, (in1 = x,))

        model = convert_to_ffg(model)

        @test nv(model) == 4 && ne(model) == 3

        model = create_model()
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