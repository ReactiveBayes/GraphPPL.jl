module test_graph_engine

using Test
using GraphPPL
using Graphs
using MetaGraphsNext
using TestSetExtensions
using StaticArrays
include("model_zoo.jl")

@testset ExtendedTestSet "graph_engine" begin
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

    @testset "getname(::NodeLabel)" begin
        import GraphPPL: ResizableArray, NodeLabel, getname

        x = NodeLabel(:x, 1)
        @test getname(x) == :x

        x = ResizableArray(NodeLabel, Val(1))
        x[1] = NodeLabel(:x, 1)
        @test getname(x) == :x

        x = ResizableArray(NodeLabel, Val(1))
        x[2] = NodeLabel(:x, 1)
        @test getname(x) == :x
    end


    @testset "setindex!(::Model, ::NodeData, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, VariableNodeData, FactorNodeData

        model = create_model()
        model[NodeLabel(:μ, 1)] = VariableNodeData(:μ, nothing)
        @test GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        @test_throws MethodError model[0] = 1

        @test_throws MethodError model["string"] = VariableNodeData(:x, nothing)
        model[NodeLabel(:x, 2)] = VariableNodeData(:x, nothing)
        @test GraphPPL.nv(model) == 2 && GraphPPL.ne(model) == 0

        model[NodeLabel(sum, 3)] = FactorNodeData(sum, nothing)
        @test GraphPPL.nv(model) == 3 && GraphPPL.ne(model) == 0
    end

    @testset "setindex!(::Model, ::EdgeLabel, ::NodeLabel, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, VariableNodeData, EdgeLabel

        model = create_model()
        μ = NodeLabel(:μ, 1)
        x = NodeLabel(:x, 2)
        model[μ] = VariableNodeData(:μ, nothing)
        model[x] = VariableNodeData(:x, nothing)
        model[μ, x] = EdgeLabel(:interface, 1)
        @test GraphPPL.ne(model) == 1

        @test_throws MethodError model[0, 1] = 1

        @test_throws KeyError model[μ, NodeLabel(:x, 100)] = EdgeLabel(:if, 1)
    end

    @testset "setindex!(::Context, ::ResizableArray{NodeLabel}, ::Symbol)" begin
        import GraphPPL: ResizableArray, Context

        context = Context()
        context[:x] = ResizableArray(NodeLabel, Val(1))
        @test haskey(context.vector_variables, :x)

        context[:y] = ResizableArray(NodeLabel, Val(2))
        @test haskey(context.tensor_variables, :y)
    end

    @testset "getindex(::Model, ::NodeLabel)" begin
        import GraphPPL: create_model, NodeLabel, VariableNodeData

        model = create_model()
        label = NodeLabel(:x, 1)
        model[label] = VariableNodeData(:x, nothing)
        @test isa(model[label], NodeData)
        @test_throws KeyError model[NodeLabel(:x, 10)]
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
        import GraphPPL: create_model, nv, ne, VariableNodeData, NodeLabel, EdgeLabel

        model = create_model()
        @test nv(model) == 0
        @test ne(model) == 0

        model[NodeLabel(:a, 1)] = VariableNodeData(:a, nothing)
        model[NodeLabel(:b, 2)] = VariableNodeData(:b, nothing)
        @test nv(model) == 2
        @test ne(model) == 0

        model[NodeLabel(:a, 1), NodeLabel(:b, 2)] = EdgeLabel(:edge, 1)
        @test nv(model) == 2
        @test ne(model) == 1
    end

    @testset "edges" begin
        import GraphPPL: edges, create_model, VariableNodeData, NodeLabel, EdgeLabel

        # Test 1: Test getting all edges from a model
        model = create_model()
        model[NodeLabel(:a, 1)] = VariableNodeData(:a, nothing)
        model[NodeLabel(:b, 2)] = VariableNodeData(:b, nothing)
        model[NodeLabel(:a, 1), NodeLabel(:b, 2)] = EdgeLabel(:edge, 1)
        @test length(edges(model)) == 1

        model[NodeLabel(:c, 2)] = VariableNodeData(:b, nothing)
        model[NodeLabel(:a, 1), NodeLabel(:c, 2)] = EdgeLabel(:edge, 2)
        @test length(edges(model)) == 2

        # Test 2: Test getting all edges from a model with a specific node
        @test edges(model, NodeLabel(:a, 1)) == [EdgeLabel(:edge, 1), EdgeLabel(:edge, 2)]
        @test edges(model, NodeLabel(:b, 2)) == [EdgeLabel(:edge, 1)]
        @test edges(model, NodeLabel(:c, 2)) == [EdgeLabel(:edge, 2)]

    end

    @testset "neighbors(::Model, ::NodeData)" begin
        import GraphPPL: create_model, neighbors, VariableNodeData, NodeLabel, EdgeLabel
        model = create_model()

        model[NodeLabel(:a, 1)] = VariableNodeData(:a, nothing)
        model[NodeLabel(:b, 2)] = VariableNodeData(:b, nothing)
        model[NodeLabel(:a, 1), NodeLabel(:b, 2)] = EdgeLabel(:edge, 1)
        @test neighbors(model, NodeLabel(:a, 1)) == [NodeLabel(:b, 2)]

        model = create_model()
        a = GraphPPL.ResizableArray(NodeLabel, Val(1))
        b = GraphPPL.ResizableArray(NodeLabel, Val(1))
        for i = 1:3
            a[i] = NodeLabel(:a, i)
            model[a[i]] = VariableNodeData(:a, nothing)
            b[i] = NodeLabel(:b, i)
            model[b[i]] = VariableNodeData(:b, nothing)
            model[a[i], b[i]] = EdgeLabel(:edge, i)
        end
        @test neighbors(model, a; sorted = true) == [b[1], b[2], b[3]]

        # Test 2: Test getting sorted neighbors
        model = create_normal_model()
        ctx = GraphPPL.getcontext(model)
        node = label_for(model.graph, 5)
        @test neighbors(model, node; sorted = true) == [
            ctx[:second_submodel_4][:w],
            ctx[:second_submodel_4][:a],
            ctx[:second_submodel_4][:b],
        ]

        # Test 3: Test getting sorted neighbors when one of the edge indices is nothing
        model = create_vector_model()
        ctx = GraphPPL.getcontext(model)
        node = ctx[:sum_12]
        @test neighbors(model, node; sorted = true) == [ctx[:out], ctx[:x][4], ctx[:y][3]]

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

    end


    @testset "to_symbol(::NodeLabel)" begin
        import GraphPPL: to_symbol, NodeLabel
        @test to_symbol(NodeLabel(:a, 1)) == :a_1
        @test to_symbol(NodeLabel(:b, 2)) == :b_2
    end

    @testset "getname" begin
        import GraphPPL: getname
        @test getname(+) == "+"
        @test getname(-) == "-"
        @test getname(sin) == "sin"
        @test getname(cos) == "cos"
        @test getname(exp) == "exp"
    end

    @testset "Context" begin
        import GraphPPL: Context

        ctx1 = Context()
        @test typeof(ctx1) == Context &&
              ctx1.prefix == "" &&
              length(ctx1.individual_variables) == 0 &&
              ctx1.depth == 0

        function test end

        ctx2 = Context(0, test, "test")
        @test typeof(ctx2) == Context &&
              ctx2.prefix == "test" &&
              length(ctx2.individual_variables) == 0 &&
              ctx2.depth == 0

        function layer end

        ctx3 = Context(ctx2, layer)
        @test typeof(ctx3) == Context &&
              ctx3.prefix == "test_layer" &&
              length(ctx3.individual_variables) == 0 &&
              ctx3.depth == 1

        @test_throws MethodError Context(ctx2, :my_model)

        function secondlayer end

        ctx5 = Context(ctx2, secondlayer)
        @test typeof(ctx5) == Context &&
              ctx5.prefix == "test_secondlayer" &&
              length(ctx5.individual_variables) == 0 &&
              ctx5.depth == 1


        ctx6 = Context(ctx3, secondlayer)
        @test typeof(ctx6) == Context &&
              ctx6.prefix == "test_layer_secondlayer" &&
              length(ctx6.individual_variables) == 0 &&
              ctx6.depth == 2
    end

    @testset "haskey(::Context)" begin
        import GraphPPL: Context

        ctx = Context()
        xlab = NodeLabel(:x, 1)
        @test !haskey(ctx.individual_variables, :x)
        ctx.individual_variables[:x] = xlab
        @test haskey(ctx.individual_variables, :x)
        @test !haskey(ctx.vector_variables, :y)
    end

    @testset "getindex(::Context, ::Symbol)" begin
        import GraphPPL: Context

        ctx = Context()
        xlab = NodeLabel(:x, 1)
        @test_throws KeyError ctx[:x]
        ctx.individual_variables[:x] = xlab
        @test ctx[:x] == xlab
    end

    @testset "getcontext(::Model)" begin
        import GraphPPL: Context, getcontext, create_model, add_variable_node!

        model = create_model()
        @test getcontext(model) == model.graph[]
        add_variable_node!(model, getcontext(model), :x)
        @test getcontext(model)[:x] == model.graph[][:x]
    end


    @testset "NodeType" begin
        import GraphPPL: NodeType, Composite, Atomic
        @test NodeType(Composite) == Atomic()
        @test NodeType(Atomic) == Atomic()
        @test NodeType(abs) == Atomic()
    end

    @testset "create_model()" begin
        import GraphPPL: create_model, Model


        model = create_model()
        @test typeof(model) <: Model && nv(model) == 0 && ne(model) == 0

        @test_throws MethodError create_model(:x, :y, :z)
    end

    @testset "copy_markov_blanket_to_child_context" begin
        import GraphPPL:
            create_model, copy_markov_blanket_to_child_context, Context, getorcreate!


        # Test 1: Copy individual variables
        model = create_model()
        ctx = getcontext(model)
        function child end
        child_context = Context(ctx, child)
        x = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)
        z = getorcreate!(model, ctx, :z, nothing)
        copy_markov_blanket_to_child_context(child_context, (in1 = x, in2 = y, out = z))
        @test child_context[:in1].name == :x

        # Test 2: Copy vector variables
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, 1)
        x = getorcreate!(model, ctx, :x, 2)
        child_context = Context(ctx, child)
        copy_markov_blanket_to_child_context(child_context, (in = x,))
        @test child_context[:in] == x

        # Test 3: Copy tensor variables
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, 1, 1)
        x = getorcreate!(model, ctx, :x, 2, 1)
        x = getorcreate!(model, ctx, :x, 1, 2)
        x = getorcreate!(model, ctx, :x, 2, 2)
        child_context = Context(ctx, child)
        copy_markov_blanket_to_child_context(child_context, (in = x,))
        @test child_context[:in] == x

        # Test 4: Do not copy constant variables
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        child_context = Context(ctx, child)
        copy_markov_blanket_to_child_context(child_context, (in = 1,))
        @test !haskey(child_context, :in)

        # Test 5: Do not copy vector valued constant variables
        model = create_model()
        ctx = getcontext(model)
        child_context = Context(ctx, child)
        copy_markov_blanket_to_child_context(child_context, (in = [1, 2, 3],))
        @test !haskey(child_context, :in)
    end

    @testset "check_variate_compatability" begin
        import GraphPPL: check_variate_compatability, NodeLabel, ResizableArray

        # Test 1: Check that a one dimensional variable is compatable with a symbol
        x = NodeLabel(:x, 1)
        @test check_variate_compatability(x, nothing)

        # Test 2: Check that an assigned vector variable returns the vector itself when called
        x = ResizableArray(NodeLabel, Val(1))
        x[1] = NodeLabel(:x, 1)
        @test check_variate_compatability(x, 1)

        #Test 3: Check that if it is not assigned, it is false
        @test !check_variate_compatability(x, 2)

        #Test 4: Check that if we overindex the array, it crashes
        @test_throws ErrorException check_variate_compatability(x, 1, 1)

        #Test 5: Check that if we underindex the array, it crashes
        x = ResizableArray(NodeLabel, Val(2))
        x[1, 1] = NodeLabel(:x, 1)
        @test_throws ErrorException check_variate_compatability(x, 1)

        #Test 6: Check that if we call an individual variable with an index, we return false
        x = NodeLabel(:x, 1)
        @test_throws ErrorException !check_variate_compatability(x, 1)

        #Test 7: Check that if we call a vector variable without an index, we return false
        x = ResizableArray(NodeLabel, Val(1))
        x[1] = NodeLabel(:x, 1)
        @test_throws ErrorException !check_variate_compatability(x, nothing)

    end

    @testset "getorcreate!" begin
        import GraphPPL: create_model, getcontext, getorcreate!

        # Test 1: Creation of regular one-dimensional variable
        model = create_model()
        ctx = getcontext(model)
        x =
            !@isdefined(x) ? getorcreate!(model, ctx, :x, nothing) :
            (check_variate_compatability(x, :x) ? x : getorcreate!(model, ctx, :x, nothing))
        @test GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        # Test 2: Ensure that getorcreating this variable again does not create a new node
        x2 =
            !@isdefined(x2) ? getorcreate!(model, ctx, :x, nothing) :
            (
                check_variate_compatability(x2, :x) ? x2 :
                getorcreate!(model, ctx, :x, nothing)
            )
        @test x == x2 && GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        # Test 3: Ensure that calling x another time gives us x benchmark
        x =
            !@isdefined(x) ? getorcreate!(model, ctx, :x, nothing) :
            (
                check_variate_compatability(x, nothing) ? x :
                getorcreate!(model, ctx, :x, nothing)
            )
        @test x == x2 && GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        # Test 4: Test that creating a vector variable creates an array of the correct size
        model = create_model()
        ctx = getcontext(model)
        y =
            !@isdefined(y) ? getorcreate!(model, ctx, :y, 1) :
            (check_variate_compatability(y, 1) ? y : getorcreate!(model, ctx, :y, [1]))
        @test GraphPPL.nv(model) == 1 &&
              GraphPPL.ne(model) == 0 &&
              y isa ResizableArray &&
              y[1] isa NodeLabel

        # Test 5: Test that recreating the same variable changes nothing
        y2 =
            !@isdefined(y2) ? getorcreate!(model, ctx, :y, 1) :
            (check_variate_compatability(y2, 1) ? y : getorcreate!(model, ctx, :y, [1]))
        @test y == y2 && GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        # Test 6: Test that adding a variable to this vector variable increases the size of the array
        y =
            !@isdefined(y) ? getorcreate!(model, ctx, :y, 2) :
            (check_variate_compatability(y, 2) ? y : getorcreate!(model, ctx, :y, [2]))
        @test GraphPPL.nv(model) == 2 &&
              y[2] isa NodeLabel &&
              haskey(ctx.vector_variables, :y)

        # Test 7: Test that getting this variable without index does not work
        @test_throws ErrorException y =
            !@isdefined(y) ? getorcreate!(model, ctx, :y, nothing) :
            (
                check_variate_compatability(y, nothing) ? y :
                getorcreate!(model, ctx, :y, nothing)
            )

        # Test 8: Test that getting this variable with an index that is too large does not work
        @test_throws ErrorException y =
            !@isdefined(y) ? getorcreate!(model, ctx, :y, 1, 2) :
            (
                check_variate_compatability(y, 1, 2) ? y :
                getorcreate!(model, ctx, :y, [1, 2])
            )

        #Test 9: Test that creating a tensor variable creates a tensor of the correct size
        model = create_model()
        ctx = getcontext(model)
        z =
            !@isdefined(z) ? getorcreate!(model, ctx, :z, 1, 1) :
            (
                check_variate_compatability(z, 1, 1) ? z :
                getorcreate!(model, ctx, :z, [1, 1])
            )
        @test GraphPPL.nv(model) == 1 &&
              GraphPPL.ne(model) == 0 &&
              z isa ResizableArray &&
              z[1, 1] isa NodeLabel

        #Test 10: Test that recreating the same variable changes nothing
        z2 =
            !@isdefined(z2) ? getorcreate!(model, ctx, :z, 1, 1) :
            (
                check_variate_compatability(z2, 1, 1) ? z :
                getorcreate!(model, ctx, :z, [1, 1])
            )
        @test z == z2 && GraphPPL.nv(model) == 1 && GraphPPL.ne(model) == 0

        #Test 11: Test that adding a variable to this tensor variable increases the size of the array
        z =
            !@isdefined(z) ? getorcreate!(model, ctx, :z, 2, 2) :
            (
                check_variate_compatability(z, 2, 2) ? z :
                getorcreate!(model, ctx, :z, [2, 2])
            )
        @test GraphPPL.nv(model) == 2 &&
              z[2, 2] isa NodeLabel &&
              haskey(ctx.tensor_variables, :z)

        #Test 12: Test that getting this variable without index does not work
        @test_throws ErrorException z =
            !@isdefined(z) ? getorcreate!(model, ctx, :z, nothing) :
            (check_variate_compatability(z, :z) ? z : getorcreate!(model, ctx, :z, nothing))

        #Test 13: Test that getting this variable with an index that is too small does not work
        @test_throws ErrorException z =
            !@isdefined(z) ? getorcreate!(model, ctx, :z, [1]) :
            (check_variate_compatability(z, 1) ? z : getorcreate!(model, ctx, :z, [1]))

        #Test 14: Test that getting this variable with an index that is too large does not work
        @test_throws ErrorException z =
            !@isdefined(z) ? getorcreate!(model, ctx, :z, [1, 2, 3]) :
            (
                check_variate_compatability(z, 1, 2, 3) ? z :
                getorcreate!(model, ctx, :z, [1, 2, 3])
            )

        # Test 15: Test that creating a variable that exists in the model scope but not in local scope still throws an error
        model = create_model()
        ctx = getcontext(model)
        for i = 1:1
            a =
                !@isdefined(a) ? getorcreate!(model, ctx, :a, nothing) :
                (
                    check_variate_compatability(a, nothing) ? a :
                    getorcreate!(model, ctx, :a, nothing)
                )
        end
        @test_throws ErrorException a =
            !@isdefined(a) ? getorcreate!(model, ctx, :a, [1]) :
            (check_variate_compatability(a, :a) ? a : getorcreate!(model, ctx, :a, [1]))
        @test_throws ErrorException a =
            !@isdefined(a) ? getorcreate!(model, ctx, :a, [1, 1]) :
            (
                check_variate_compatability(a, 1, 2) ? a :
                getorcreate!(model, ctx, :a, [1, 1])
            )
    end

    @testset "getifcreated" begin
        import GraphPPL:
            create_model,
            getifcreated,
            getorcreate!,
            getcontext,
            getname,
            value,
            getorcreate!
        model = create_model()
        ctx = getcontext(model)

        # Test case 1: check that getifcreated  the variable created by getorcreate
        x = getorcreate!(model, ctx, :x, nothing)
        @test getifcreated(model, ctx, x) == x

        # Test case 2: check that getifcreated returns the variable created by getorcreate in a vector
        y = getorcreate!(model, ctx, :y, [1])
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
        ctx = getcontext(model)
        z = getorcreate!(model, ctx, :z, 1)
        z_fetched = getifcreated(model, ctx, z[1])
        @test z_fetched == z[1]


        # Test case 11: Test that getifcreated returns a constant node when we call it with a symbol
        model = create_model()
        ctx = getcontext(model)
        z = getifcreated(model, ctx, :Bernoulli)
        @test value(model[z]) == :Bernoulli

        # Test case 12: Test that getifcreated returns a vector of NodeLabels if called with a vector of NodeLabels
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)
        z = getifcreated(model, ctx, [x, y])
        @test z == [x, y]

        # Test case 13: Test that getifcreated returns a ResizableArray tensor of NodeLabels if called with a ResizableArray tensor of NodeLabels
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, 1, 1)
        x = getorcreate!(model, ctx, :x, 2, 1)
        z = getifcreated(model, ctx, x)
        @test z == x

        # Test case 14: Test that getifcreated returns multiple variables if called with a tuple of constants
        model = create_model()
        ctx = getcontext(model)
        z = getifcreated(model, ctx, ([1, 1], 2))
        @test GraphPPL.nv(model) == 2 &&
              GraphPPL.value(model[z[1]]) == [1, 1] &&
              GraphPPL.value(model[z[2]]) == 2

    end


    @testset "add_variable_node!" begin
        import GraphPPL: create_model, add_variable_node!, getcontext, node_options

        # Test 1: simple add variable to model
        model = create_model()
        ctx = getcontext(model)
        node_id = add_variable_node!(model, ctx, :x)
        @test nv(model) == 1 &&
              haskey(ctx.individual_variables, :x) &&
              ctx.individual_variables[:x] == node_id

        # Test 2: Add second variable to model
        add_variable_node!(model, ctx, :y)
        @test nv(model) == 2 && haskey(ctx, :y)

        # Test 3: Check that adding an integer variable throws a MethodError
        @test_throws MethodError add_variable_node!(model, ctx, 1)

        # Test 4: Add a vector variable to the model
        model = create_model()
        ctx = getcontext(model)
        ctx.vector_variables[:x] = ResizableArray(NodeLabel, Val(1))
        node_id = add_variable_node!(model, ctx, :x; index = 2)
        @test nv(model) == 1 &&
              haskey(ctx, :x) &&
              ctx[:x][2] == node_id &&
              length(ctx[:x]) == 2

        # Test 5: Add a second vector variable to the model
        node_id = add_variable_node!(model, ctx, :x; index = 1)
        @test nv(model) == 2 &&
              haskey(ctx, :x) &&
              ctx[:x][1] == node_id &&
              length(ctx[:x]) == 2

        # Test 6: Add a tensor variable to the model
        model = create_model()
        ctx = getcontext(model)
        ctx.tensor_variables[:x] = ResizableArray(NodeLabel, Val(2))
        node_id = add_variable_node!(model, ctx, :x; index = (2, 3))
        @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2, 3] == node_id

        # Test 7: Add a second tensor variable to the model
        node_id = add_variable_node!(model, ctx, :x; index = (2, 4))
        @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][2, 4] == node_id

        # Test 9: Add a variable with a non-integer index
        model = create_model()
        ctx = getcontext(model)
        ctx.tensor_variables[:z] = ResizableArray(NodeLabel, Val(2))
        @test_throws MethodError add_variable_node!(model, ctx, :z; index = (1, "a"))

        # Test 10: Add a variable with a negative index
        ctx.vector_variables[:x] = ResizableArray(NodeLabel, Val(1))
        @test_throws BoundsError add_variable_node!(model, ctx, :x; index = -1)

        # Test 11: Add a variable with options
        model = create_model()
        ctx = getcontext(model)
        var = add_variable_node!(
            model,
            ctx,
            :x,
            __options__ = NamedTuple((:isconstrained => true,)),
        )
        @test nv(model) == 1 &&
              haskey(ctx, :x) &&
              ctx[:x] == var &&
              node_options(model[var]) ==
              NamedTuple((:isconstrained => true, :index => nothing))

    end

    @testset "add_atomic_factor_node!" begin
        import GraphPPL: create_model, add_atomic_factor_node!, getorcreate!, node_options

        # Test 1: Add an atomic factor node to the model
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        node_id = add_atomic_factor_node!(model, ctx, sum)
        @test nv(model) == 2 && getname(label_for(model.graph, 2)) == sum

        # Test 2: Add a second atomic factor node to the model with the same name and assert they are different
        node_id = add_atomic_factor_node!(model, ctx, sum)
        @test nv(model) == 3 && getname(label_for(model.graph, 3)) == sum

        # Test 3: Add an atomic factor node with options
        node_id = add_atomic_factor_node!(
            model,
            ctx,
            sum;
            __options__ = Dict(:isconstrained => true),
        )
        @test node_options(model[node_id]) == Dict(:isconstrained => true)


        #Test 4: Make sure alias is added
        node_id = add_atomic_factor_node!(
            model,
            ctx,
            sum;
            __options__ = Dict(:isconstrained => true),
        )
        @test getname(node_id) == sum

        # Test 5: Test that creating a node with an instantiated object is supported

        model = create_model()
        ctx = getcontext(model)
        prior = Normal(0, 1)
        node_id = add_atomic_factor_node!(model, ctx, prior)
        @test GraphPPL.nv(model) == 1 && getname(label_for(model.graph, 1)) == Normal(0, 1)
    end

    @testset "add_composite_factor_node!" begin
        import GraphPPL: create_model, add_composite_factor_node!, getcontext, to_symbol

        # Add a composite factor node to the model
        model = create_model()
        parent_ctx = getcontext(model)
        child_ctx = getcontext(model)
        add_variable_node!(model, child_ctx, :x)
        add_variable_node!(model, child_ctx, :y)
        node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :f)
        node_name = to_symbol(node_id)
        @test nv(model) == 2 &&
              haskey(parent_ctx.factor_nodes, node_name) &&
              parent_ctx.factor_nodes[node_name] === child_ctx &&
              length(child_ctx.individual_variables) == 2


        # Add a composite factor node with a different name
        node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :g)
        node_name = to_symbol(node_id)
        @test nv(model) == 2 &&
              haskey(parent_ctx.factor_nodes, node_name) &&
              parent_ctx.factor_nodes[node_name] === child_ctx &&
              length(child_ctx.individual_variables) == 2

        # Add a composite factor node with an empty child context
        empty_ctx = Context()
        node_id = add_composite_factor_node!(model, parent_ctx, empty_ctx, :h)
        node_name = to_symbol(node_id)
        @test nv(model) == 2 &&
              haskey(parent_ctx.factor_nodes, node_name) &&
              parent_ctx.factor_nodes[node_name] === empty_ctx &&
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
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)
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
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)

        variable_nodes = [getorcreate!(model, ctx, i, nothing) for i in [:a, :b, :c]]
        add_edge!(model, y, variable_nodes, :interface)

        @test ne(model) == 3 &&
              model.graph[y, variable_nodes[1]] == EdgeLabel(:interface, 1)
    end

    @testset "rhs_to_named_tuple()" begin
        import GraphPPL: rhs_to_named_tuple

        # Test 1: Add default arguments to Normal call
        @test rhs_to_named_tuple(Atomic(), Normal, [0, 1]) == (μ = 0, σ = 1)

        # Test 2: Add :in to function call that has default behaviour 
        @test rhs_to_named_tuple(Atomic(), +, [1, 2]) == (in = (1, 2),)

        # Test 3: Add :in to function call that has default behaviour with nested interfaces
        @test rhs_to_named_tuple(Atomic(), +, [[1, 1], 2]) == (in = ([1, 1], 2),)

        struct CompositeNode end
        GraphPPL.NodeType(::Type{CompositeNode}) = GraphPPL.Composite()
        @test_throws ErrorException GraphPPL.rhs_to_named_tuple(
            Composite(),
            CompositeNode,
            [1, 2],
        )
    end

    @testset "make_node!(::Atomic)" begin
        import GraphPPL: make_node!, create_model, getorcreate!

        # Test 1: Deterministic call returns result of deterministic function and does not create new node
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        @test make_node!(model, ctx, +, x, [1, 1]) == 2
        @test make_node!(model, ctx, sin, x, [0]) == 0
        @test GraphPPL.nv(model) == 1

        # Test 2: Stochastic atomic call returns a new node
        node_id = make_node!(model, ctx, Normal, x, (μ = 0, σ = 1))
        @test GraphPPL.nv(model) == 4
        @test GraphPPL.edges(model, GraphPPL.label_for(model.graph, 2)) ==
              GraphPPL.EdgeLabel[
            GraphPPL.EdgeLabel(:out, nothing),
            GraphPPL.EdgeLabel(:μ, nothing),
            GraphPPL.EdgeLabel(:σ, nothing),
        ]

        # Test 3: Stochastic atomic call with an AbstractArray as rhs_interfaces
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        make_node!(model, ctx, Normal, x, [0, 1])
        @test GraphPPL.nv(model) == 4 && GraphPPL.ne(model) == 3

        # Test 4: Deterministic atomic call with nodelabels should create the actual node
        model = create_model()
        ctx = getcontext(model)
        in1 = getorcreate!(model, ctx, :in1, nothing)
        in2 = getorcreate!(model, ctx, :in2, nothing)
        out = getorcreate!(model, ctx, :out, nothing)
        make_node!(model, ctx, +, out, [in1, in2])
        @test GraphPPL.nv(model) == 4 && GraphPPL.ne(model) == 3

        # Test 5: Deterministic atomic call with nodelabels should create the actual node
        model = create_model()
        ctx = getcontext(model)
        in1 = getorcreate!(model, ctx, :in1, nothing)
        in2 = getorcreate!(model, ctx, :in2, nothing)
        out = getorcreate!(model, ctx, :out, nothing)
        make_node!(model, ctx, +, out, (in = [in1, in2],))
        @test GraphPPL.nv(model) == 4

        # Test 6: Stochastic node with default arguments
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        node_id = make_node!(model, ctx, Normal, x, [0, 1])
        @test GraphPPL.nv(model) == 4
        @test GraphPPL.edges(model, GraphPPL.label_for(model.graph, 2)) ==
              GraphPPL.EdgeLabel[
            GraphPPL.EdgeLabel(:out, nothing),
            GraphPPL.EdgeLabel(:μ, nothing),
            GraphPPL.EdgeLabel(:σ, nothing),
        ]

        # Test 7: Stochastic node with instantiated object
        model = create_model()
        ctx = getcontext(model)
        prior = Normal(0, 1)
        x = getorcreate!(model, ctx, :x, nothing)
        node_id = make_node!(model, ctx, prior, x, nothing)
        @test GraphPPL.nv(model) == 2

        # Test 8: Deterministic node with nodelabel objects where all interfaces are already defined (no missing interfaces)
        model = create_model()
        ctx = getcontext(model)
        in1 = getorcreate!(model, ctx, :in1, nothing)
        in2 = getorcreate!(model, ctx, :in2, nothing)
        out = getorcreate!(model, ctx, :out, nothing)
        @test_throws AssertionError make_node!(model, ctx, +, out, (in = in1, out = in2))

        # Test 8: Stochastic node with nodelabel objects where we have an array on the rhs (so should create 1 node for [0, 1])
        model = create_model()
        ctx = getcontext(model)
        out = getorcreate!(model, ctx, :out, nothing)
        make_node!(model, ctx, ArbitraryNode, out, (in = [0, 1],))

        @test GraphPPL.nv(model) == 3 &&
              GraphPPL.node_options(model[ctx[:constvar_2]])[:value] == [0, 1]

        # Test 9: Stochastic node with all interfaces defined as constants
        model = create_model()
        ctx = getcontext(model)
        out = getorcreate!(model, ctx, :out, nothing)
        make_node!(model, ctx, ArbitraryNode, out, [1, 1]; __debug__ = false)
        @test GraphPPL.nv(model) == 4
        @test GraphPPL.edges(model, GraphPPL.label_for(model.graph, 2)) ==
              GraphPPL.EdgeLabel[
            GraphPPL.EdgeLabel(:out, nothing),
            GraphPPL.EdgeLabel(:in, 1),
            GraphPPL.EdgeLabel(:in, 2),
        ]

        #Test 10: Deterministic node with keyword arguments
        function abc(; a = 1, b = 2)
            return a + b
        end
        model = create_model()
        ctx = getcontext(model)
        out = getorcreate!(model, ctx, :out, nothing)
        out = make_node!(model, ctx, abc, out, (a = 1, b = 2))
        @test out == 3

        # Test 11: Deterministic node with mixed arguments
        function abc(a; b = 2)
            return a + b
        end
        model = create_model()
        ctx = getcontext(model)
        out = getorcreate!(model, ctx, :out, nothing)
        out = make_node!(model, ctx, abc, out, GraphPPL.MixedArguments([2], (b = 2,)))
        @test out == 4

        # Test 12: Deterministic node with mixed arguments that has to be materialized should throw error
        model = create_model()
        ctx = getcontext(model)
        out = getorcreate!(model, ctx, :out, nothing)
        a = getorcreate!(model, ctx, :a, nothing)
        @test_throws ErrorException make_node!(
            model,
            ctx,
            abc,
            out,
            GraphPPL.MixedArguments([a], (b = 2,)),
        )

        # Test 13: Make stochastic node with aliases
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        node_id = make_node!(model, ctx, Normal, x, (μ = 0, τ = 1))
        @test any(
            (key) -> occursin("NormalMeanPrecision", String(key)),
            keys(ctx.factor_nodes),
        )
        @test GraphPPL.nv(model) == 4

        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        node_id = make_node!(model, ctx, Normal, x, (μ = 0, σ = 1))
        @test any(
            (key) -> occursin("NormalMeanVariance", String(key)),
            keys(ctx.factor_nodes),
        )
        @test GraphPPL.nv(model) == 4

        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        node_id = make_node!(model, ctx, Normal, x, [0, 1])
        @test any(
            (key) -> occursin("NormalMeanVariance", String(key)),
            keys(ctx.factor_nodes),
        )
        @test GraphPPL.nv(model) == 4

    end

    @testset "make_node!(::Composite)" begin

        #test make node for priors
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        make_node!(model, ctx, prior, x, [])
        @test GraphPPL.nv(model) == 4

        #test make node for other composite models
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        @test_throws ErrorException make_node!(model, ctx, second_submodel, x, [0, 1])

    end

    @testset "prune!(m::Model)" begin
        import GraphPPL: prune!, create_model, getorcreate!, add_edge!

        # Test 1: Prune a node with no edges
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        prune!(model)
        @test GraphPPL.nv(model) == 0

        # Test 2: Prune two nodes
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)
        z = getorcreate!(model, ctx, :z, nothing)
        w = getorcreate!(model, ctx, :w, nothing)

        add_edge!(model, y, z, :test)
        prune!(model)
        @test GraphPPL.nv(model) == 2

    end

    @testset "broadcast" begin
        import GraphPPL: NodeLabel, ResizableArray

        # Test 1: Broadcast a vector node
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, 1)
        x = getorcreate!(model, ctx, :x, 2)
        y = getorcreate!(model, ctx, :y, 1)
        y = getorcreate!(model, ctx, :y, 2)
        z = broadcast(
            (x_, y_) -> begin
                var = make_node!(model, ctx, +, nothing, [x_, y_])
            end,
            x,
            y,
        )
        @test size(z) == (2,)

        # Test 2: Broadcast a matrix node
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, 1, 1)
        x = getorcreate!(model, ctx, :x, 1, 2)
        x = getorcreate!(model, ctx, :x, 2, 1)
        x = getorcreate!(model, ctx, :x, 2, 2)

        y = getorcreate!(model, ctx, :y, 1, 1)
        y = getorcreate!(model, ctx, :y, 1, 2)
        y = getorcreate!(model, ctx, :y, 2, 1)
        y = getorcreate!(model, ctx, :y, 2, 2)
        z = broadcast(
            (x_, y_) -> begin
                var = make_node!(model, ctx, +, nothing, [x_, y_])
            end,
            x,
            y,
        )
        @test size(z) == (2, 2)

        # Test 3: Broadcast a vector node with a matrix node
        model = create_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, 1)
        x = getorcreate!(model, ctx, :x, 2)
        y = getorcreate!(model, ctx, :y, 1, 1)
        y = getorcreate!(model, ctx, :y, 1, 2)
        y = getorcreate!(model, ctx, :y, 2, 1)
        y = getorcreate!(model, ctx, :y, 2, 2)
        z = broadcast(
            (x_, y_) -> begin
                var = make_node!(model, ctx, +, nothing, [x_, y_])
            end,
            x,
            y,
        )
        @test size(z) == (2, 2)

    end
end

end
