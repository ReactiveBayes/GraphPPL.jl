module test_modular_graphs

using Test
using GraphPPL
using Graphs
using MetaGraphsNext
using TestSetExtensions

@testset "graph_engine" begin
    @testset "model constructor" begin
        import GraphPPL: Model, NodeLabel, NodeData, Context, EdgeLabel

        g = MetaGraph(
            Graph(),
            label_type = NodeLabel,
            vertex_data_type = NodeData,
            graph_data = Context(),
            edge_data_type = EdgeLabel,
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

    @testset "generate_nodelabel(::Model, ::Symbol)" begin
        import GraphPPL: create_model, gensym, NodeLabel, generate_nodelabel

        model = create_model()
        first_sym = generate_nodelabel(model, :x)
        @test typeof(first_sym) == NodeLabel

        second_sym = generate_nodelabel(model, :x)
        @test first_sym != second_sym && first_sym.name == second_sym.name

        id = generate_nodelabel(model, :c)
        @test id.name == :c && id.index == 3


        id = generate_nodelabel(model, "d")
        @test id.name == :d && id.index == 4 && id.variable_type == 1


        id = generate_nodelabel(model, :d, 3)
        @test id.name == :d && id.index == 5 && id.variable_type == 2

        id = generate_nodelabel(model, :d, (2, 1))
        @test id.name == :d && id.index == 6 && id.variable_type == 3

        id = generate_nodelabel(model, "d", (2, 1))
        @test id.name == :d && id.index == 7 && id.variable_type == 3

        id = generate_nodelabel(model, "d", 2)
        @test id.name == :d && id.index == 8 && id.variable_type == 2

        @test_throws ArgumentError generate_nodelabel(model, :d, (2, "a"))

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

    @testset "create_model()" begin
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
            getorcreate!,
            getorcreatearray!
   

        # Test 1: Copy individual variables
        model = create_model()
        ctx = context(model)
        child_context = Context(context(model), "child")
        x = getorcreate!(model, ctx, :x)
        y = getorcreate!(model, ctx, :y)
        z = getorcreate!(model, ctx, :z)
        copy_markov_blanket_to_child_context(child_context, (in1 = x, in2 = y, out = z))
        @test child_context[:in1].name == :x

        # Test 2: Copy vector variables
        model = create_model()
        ctx = context(model)
        x = getorcreatearray!(model, ctx, :x, Val(1))
        getorcreate!(model, ctx, :x, 1)
        getorcreate!(model, ctx, :x, 2)
        child_context = Context(context(model), "child")
        copy_markov_blanket_to_child_context(child_context, (in1 = x,))
        @test child_context[:in1] == x

        # Test 3: Copy tensor variables
        model = create_model()
        ctx = context(model)
        x = getorcreatearray!(model, ctx, :x, Val(2))
        getorcreate!(model, ctx, :x, 1, 1)
        getorcreate!(model, ctx, :x, 2, 1)
        getorcreate!(model, ctx, :x, 1, 2)
        getorcreate!(model, ctx, :x, 2, 2)
        child_context = Context(context(model), "child")
        copy_markov_blanket_to_child_context(child_context, (in1 = x,))
        @test child_context[:in1] == x
    end


    @testset "getorcreate!" begin
        import GraphPPL: create_model, getorcreate!, Context

        #Test case 1: create a new variable
        model = create_model()
        ctx = context(model)
        getorcreate!(model, ctx, :x)
        @test nv(model) == 1

        #Test case 2: check that getorcreate contains the same variable
        x = getorcreate!(model, ctx, :x)
        @test nv(model) == 1 && x == getorcreate!(model, ctx, :x)

        #Test case 3: create a new variable
        y = getorcreate!(model, ctx, :y)
        @test nv(model) == 2

        #Test case 4: create a tuple of variables
        (in1, in2) = getorcreate!(model, ctx, [:in_1, :in2])
        @test nv(model) == 4

        #Test case 5: test that you cannot create integer variables
        @test_throws MethodError getorcreate!(model, ctx, 1)

        #Test case 6: test that two variables in two different contexts from the same markov blanket are the same variables in the model
        child_context = Context(context(model), "child")
        copy_markov_blanket_to_child_context(child_context, (in = x, out = y))
        @test getorcreate!(model, child_context, :in) == getorcreate!(model, ctx, :x)

    end

    @testset "getorcreatearray!" begin
        import GraphPPL: create_model, getorcreatearray!, context

        #Test case 1: test creation of a vector variable
        model = create_model()
        ctx = context(model)
        v = getorcreatearray!(model, ctx, :v, Val(1))
        @test haskey(context(model).vector_variables, :v)

        # Test case 2: test creation of a tensor variable
        mv = getorcreatearray!(model, context(model), :mv, Val(2))
        @test haskey(context(model).tensor_variables, :mv)

        # Test case 3: test that creation of individual variable if it is already a vector variable throws an error
        @test_throws ErrorException getorcreate!(model, context(model), :mv)
    end

    @testset "getorcreate!" begin
        import GraphPPL:
            create_model, getorcreatearray!, getorcreate!, getorcreate!, context

        # Test case 1: test that iteratively creates new variables and should dynamically grow the array
        model = create_model()
        ctx = context(model)
        mv = getorcreatearray!(model, ctx, :mv, Val(2))
        c = 0
        for i = 1:10
            for j = 1:3
                c += 1
                getorcreate!(model, ctx, :mv, i, j)
                @test nv(model) == c
            end
        end

        # Test case 11: test that getting an out-of-bounds tensor variable resizes the tensor
        model = create_model()
        ctx = context(model)
        mv = getorcreatearray!(model, ctx, :mv, Val(2))
        getorcreate!(model, context(model), :mv, 2, 3)
        getorcreate!(model, context(model), :mv, 2, 1)
        @test size(context(model)[:mv]) == (2, 3)
        @test haskey(context(model).tensor_variables, :mv)
        @test nv(model) == 2
        getorcreate!(model, context(model), :mv, 2, 4)
        @test nv(model) == 3
        @test context(model)[:mv][2, 4] == mv[2, 4]
        @test size(context(model)[:mv]) == (2, 4)

    end

    @testset "getifcreated" begin
        import GraphPPL:
            create_model,
            getifcreated,
            getorcreate!,
            context,
            name,
            value,
            getorcreatearray!,
            getorcreate!
        model = create_model()
        ctx = context(model)

        # Test case 1: check that getifcreated  the variable created by getorcreate
        x = getorcreate!(model, ctx, :x)
        @test getifcreated(model, ctx, x) == x

        # Test case 2: check that getifcreated returns the variable created by getorcreate in a vector
        y = getorcreatearray!(model, ctx, :y, Val(1))
        getorcreate!(model, ctx, :y, 1)
        @test getifcreated(model, ctx, y[1]) == y[1]

        # Test case 3: check that getifcreated returns a new variable node when called with integer input
        c = getifcreated(model, ctx, 1)
        @test GraphPPL.value(model[c]) == 1

        # Test case 4: check that getifcreated returns a new variable node when called with a vector input
        c = getifcreated(model, ctx, [1, 2])
        @test GraphPPL.value(model[c]) == [1, 2]

        # Test case 5: check that getifcreated returns a tuple of variable nodes when called with a tuple of NodeData
        output = getifcreated(model, ctx, (x, y[1]))
        @test output == (x, y[1])

        # Test case 6: check that getifcreated returns a tuple of new variable nodes when called with a tuple of integers
        output = getifcreated(model, ctx, (1, 2))
        @test GraphPPL.value(model[output[1]]) == 1
        @test GraphPPL.value(model[output[2]]) == 2

        # Test case 7: check that getifcreated returns a tuple of variable nodes when called with a tuple of mixed input
        output = getifcreated(model, ctx, (x, 1))
        @test output[1] == x && GraphPPL.value(model[output[2]]) == 1

        # Test case 10: check that getifcreated returns the variable node if we create a variable and call it by symbol in a vector
        model = create_model()
        ctx = context(model)
        z = getorcreatearray!(model, ctx, :z, Val(1))
        getorcreate!(model, ctx, :z, 1)
        z_fetched = getifcreated(model, ctx, z[1])
        @test z_fetched == z[1]


        # Test case 11: Test that getifcreated returns a constant node when we call it with a symbol
        model = create_model()
        ctx = context(model)
        z = getifcreated(model, ctx, :Bernoulli)
        @test value(model[z]) == :Bernoulli

    end

    @testset "add_variable_node!" begin
        import GraphPPL: create_model, add_variable_node!, context, getorcreatearray!

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
        getorcreatearray!(model, ctx, :x, Val(1))
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
        getorcreatearray!(model, ctx, :x, Val(2))
        node_id = add_variable_node!(model, ctx, :x, (2, 3))
        @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2, 3] == node_id

        #add a second tensor variable to the model
        node_id = add_variable_node!(model, ctx, :x, (2, 4))
        @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][2, 4] == node_id

        # Attempt to add a variable with an existing index
        model = create_model()
        ctx = context(model)
        getorcreatearray!(model, ctx, :y, Val(1))
        node_id = add_variable_node!(model, ctx, :y, 1)
        node_id = add_variable_node!(model, ctx, :y, 1)


        # Add a variable with a non-integer index
        getorcreatearray!(model, ctx, :z, Val(2))
        @test_throws ArgumentError add_variable_node!(model, ctx, :z, (1, "a"))

        # Add a variable with a negative index
        getorcreatearray!(model, ctx, :w, Val(1))
        @test_throws BoundsError add_variable_node!(model, ctx, :w, -1)

    end

    @testset "add_atomic_factor_node!" begin
        import GraphPPL: create_model, add_atomic_factor_node!, getorcreate!

        model = create_model()
        ctx = context(model)
        getorcreate!(model, ctx, :x)
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
            create_model,
            nv,
            ne,
            NodeData,
            NodeLabel,
            EdgeLabel,
            add_edge!,
            getorcreate!,
            generate_nodelabel

        model = create_model()
        ctx = context(model)
        x = getorcreate!(model, ctx, :x)
        y = getorcreate!(model, ctx, :y)
        add_edge!(model, x, y, :interface)


        @test ne(model) == 1

        @test_throws MethodError add_edge!(model, x, y, 123)

        @test_throws KeyError add_edge!(
            model,
            generate_nodelabel(model, :factor_node),
            generate_nodelabel(model, :factor_node2),
            :interface,
        )


    end

    @testset "add_edge!(::Model, ::NodeLabel, ::Vector{NodeLabel}, ::Symbol)" begin
        import GraphPPL:
            create_model, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!
        model = create_model()
        ctx = context(model)
        x = getorcreate!(model, ctx, :x)
        y = getorcreate!(model, ctx, :y)

        variable_nodes = [getorcreate!(model, ctx, i) for i in [:a, :b, :c]]
        add_edge!(model, y, variable_nodes, :interface)

        @test ne(model) == 3
    end


    @testset "make_node!(::Atomic)" begin
        import GraphPPL: create_model, make_node!, plot_graph, getorcreate!, getifcreated

        model = create_model()
        ctx = context(model)

        θ = getorcreate!(model, ctx, :x)
        τ = getorcreate!(model, ctx, :y)
        μ = getorcreate!(model, ctx, :w)
        make_node!(
            model,
            context(model),
            sum,
            (
                in1 = getifcreated(model, context(model), θ),
                in2 = getifcreated(model, context(model), τ),
                out = getifcreated(model, context(model), μ),
            ),
        )
        @test nv(model) == 4 && ne(model) == 3



        w = getorcreate!(model, ctx, :w)
        y = getorcreate!(model, ctx, :y)
        z = getorcreate!(model, ctx, :z)
        make_node!(
            model,
            context(model),
            sum,
            (
                in1 = getifcreated(model, context(model), w),
                in2 = getifcreated(model, context(model), y),
                out = getifcreated(model, context(model), z),
            ),
        )
        @test nv(model) == 6 && ne(model) == 6



        model = create_model()
        ctx = context(model)
        f = sum
        θ = getorcreate!(model, ctx, :x)
        τ = getorcreate!(model, ctx, :y)
        μ = getorcreate!(model, ctx, :w)
        make_node!(
            model,
            context(model),
            f,
            (
                in1 = getifcreated(model, context(model), θ),
                in2 = getifcreated(model, context(model), τ),
                out = getifcreated(model, context(model), μ),
            ),
        )
        @test nv(model) == 4 && ne(model) == 3

        model = create_model()
        make_node!(model, context(model), sum, NamedTuple())
        @test nv(model) == 1


        model = create_model()
        z = getorcreate!(model, ctx, :z)
        make_node!(
            model,
            context(model),
            sum,
            (
                in1 = getifcreated(model, context(model), 1),
                in2 = getifcreated(model, context(model), 2),
                out = getifcreated(model, context(model), z),
            ),
        )
        @test nv(model) == 4 && ne(model) == 3

    end

    @testset "make_node_from_object" begin
        import GraphPPL: create_model, getorcreate!, make_node_from_object!, context
        struct Normal
            μ::Real
            σ::Real
        end

        # Test 1: make_node_from_object with a variable node

        model = create_model()
        ctx = context(model)
        x = getorcreate!(model, ctx, :x)
        y = make_node_from_object!(model, ctx, x, :y)
        @test x == y && nv(model) == 1

        # Test 2: make_node_from_object with a distribution

        model = create_model()
        ctx = context(model)
        x = Normal(0, 1)
        y = make_node_from_object!(model, ctx, x, :y)
        @test nv(model) == 4 && y isa NodeLabel

        # Test 3: make_node_from_object with an indexed node

        model = create_model()
        ctx = context(model)
        x = Normal(0, 1)
        y = getorcreatearray!(model, ctx, :y, Val(1))
        y[1] = make_node_from_object!(model, ctx, x, :y, 1)
        @test nv(model) == 4 && y[1] isa NodeLabel

        # Test 4: make_node_from_object with indexed statement on the left and label right

        model = create_model()
        ctx = context(model)
        x = getorcreate!(model, ctx, :x)
        y = getorcreatearray!(model, ctx, :y, Val(1))
        y[1] = make_node_from_object!(model, ctx, x, :y, 1)
        @test nv(model) == 1 && y[1] isa NodeLabel
    end

end

end
