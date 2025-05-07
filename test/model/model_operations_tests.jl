@testitem "getindex(::Model, ::NodeLabel)" setup = [TestUtils] begin
    import GraphPPL: create_model, getcontext, NodeLabel, NodeData, VariableNodeProperties, getproperties

    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    label = NodeLabel(:x, 1)
    model[label] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    @test isa(model[label], NodeData)
    @test isa(getproperties(model[label]), VariableNodeProperties)
    @test_throws KeyError model[NodeLabel(:x, 10)]
    @test_throws MethodError model[0]
end

@testitem "copy_markov_blanket_to_child_context" setup = [TestUtils] begin
    import GraphPPL:
        create_model, copy_markov_blanket_to_child_context, Context, getorcreate!, proxylabel, unroll, getcontext, NodeCreationOptions

    # Copy individual variables
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    function child end
    child_context = Context(ctx, child)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    y = getorcreate!(model, ctx, NodeCreationOptions(), :y, nothing)
    zref = getorcreate!(model, ctx, NodeCreationOptions(), :z, nothing)

    # Do not copy constant variables
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = 1,))
    @test !haskey(child_context, :in)

    # Do not copy vector valued constant variables
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = [1, 2, 3],))
    @test !haskey(child_context, :in)

    # Copy ProxyLabel variables to child context
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    xref = proxylabel(:x, xref, nothing)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = xref,))
    @test child_context[:in] == xref
end

@testitem "getorcreate!" setup = [TestUtils] begin
    using Graphs
    import GraphPPL:
        create_model,
        getcontext,
        getorcreate!,
        check_variate_compatability,
        NodeLabel,
        ResizableArray,
        NodeCreationOptions,
        getproperties,
        is_kind

    let # let block to suppress the scoping warnings
        # Test 1: Creation of regular one-dimensional variable
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        x = getorcreate!(model, ctx, :x, nothing)
        @test nv(model) == 1 && ne(model) == 0

        # Test 2: Ensure that getorcreating this variable again does not create a new node
        x2 = getorcreate!(model, ctx, :x, nothing)
        @test x == x2 && nv(model) == 1 && ne(model) == 0

        # Test 3: Ensure that calling x another time gives us x
        x = getorcreate!(model, ctx, :x, nothing)
        @test x == x2 && nv(model) == 1 && ne(model) == 0

        # Test 4: Test that creating a vector variable creates an array of the correct size
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        y = getorcreate!(model, ctx, :y, 1)
        @test nv(model) == 1 && ne(model) == 0 && y isa ResizableArray && y[1] isa NodeLabel

        # Test 5: Test that recreating the same variable changes nothing
        y2 = getorcreate!(model, ctx, :y, 1)
        @test y == y2 && nv(model) == 1 && ne(model) == 0

        # Test 6: Test that adding a variable to this vector variable increases the size of the array
        y = getorcreate!(model, ctx, :y, 2)
        @test nv(model) == 2 && y[2] isa NodeLabel && haskey(ctx.vector_variables, :y)

        # Test 7: Test that getting this variable without index does not work
        @test_throws ErrorException getorcreate!(model, ctx, :y, nothing)

        # Test 8: Test that getting this variable with an index that is too large does not work
        @test_throws ErrorException getorcreate!(model, ctx, :y, 1, 2)

        #Test 9: Test that creating a tensor variable creates a tensor of the correct size
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        z = getorcreate!(model, ctx, :z, 1, 1)
        @test nv(model) == 1 && ne(model) == 0 && z isa ResizableArray && z[1, 1] isa NodeLabel

        #Test 10: Test that recreating the same variable changes nothing
        z2 = getorcreate!(model, ctx, :z, 1, 1)
        @test z == z2 && nv(model) == 1 && ne(model) == 0

        #Test 11: Test that adding a variable to this tensor variable increases the size of the array
        z = getorcreate!(model, ctx, :z, 2, 2)
        @test nv(model) == 2 && z[2, 2] isa NodeLabel && haskey(ctx.tensor_variables, :z)

        #Test 12: Test that getting this variable without index does not work
        @test_throws ErrorException z = getorcreate!(model, ctx, :z, nothing)

        #Test 13: Test that getting this variable with an index that is too small does not work
        @test_throws ErrorException z = getorcreate!(model, ctx, :z, 1)

        #Test 14: Test that getting this variable with an index that is too large does not work
        @test_throws ErrorException z = getorcreate!(model, ctx, :z, 1, 2, 3)

        # Test 15: Test that creating a variable that exists in the model scope but not in local scope still throws an error
        let # force local scope
            model = TestUtils.create_test_model()
            ctx = getcontext(model)
            getorcreate!(model, ctx, :a, nothing)
            @test_throws ErrorException a = getorcreate!(model, ctx, :a, 1)
            @test_throws ErrorException a = getorcreate!(model, ctx, :a, 1, 1)
        end

        # Test 16. Test that the index is required to create a variable in the model
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        @test_throws ErrorException getorcreate!(model, ctx, :a)
        @test_throws ErrorException getorcreate!(model, ctx, NodeCreationOptions(), :a)
        @test_throws ErrorException getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a)
        @test_throws ErrorException getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 2), :a)

        # Test 17. Range based getorcreate!
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, :a, 1:2)
        @test nv(model) == 2 && var[1] isa NodeLabel && var[2] isa NodeLabel

        # Test 17.1 Range based getorcreate! should use the same options
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, 1:2)
        @test nv(model) == 2 && var[1] isa NodeLabel && var[2] isa NodeLabel
        @test is_kind(getproperties(model[var[1]]), :data)
        @test is_kind(getproperties(model[var[1]]), :data)

        # Test 18. Range x2 based getorcreate!
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, :a, 1:2, 1:3)
        @test nv(model) == 6
        for i in 1:2, j in 1:3
            @test var[i, j] isa NodeLabel
        end

        # Test 18. Range x2 based getorcreate! should use the same options
        model = TestUtils.create_test_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, 1:2, 1:3)
        @test nv(model) == 6
        for i in 1:2, j in 1:3
            @test var[i, j] isa NodeLabel
            @test is_kind(getproperties(model[var[i, j]]), :data)
        end
    end
end

@testitem "getifcreated" setup = [TestUtils] begin
    using Graphs
    import GraphPPL:
        create_model,
        getifcreated,
        getorcreate!,
        getcontext,
        getproperties,
        getname,
        value,
        getorcreate!,
        proxylabel,
        value,
        NodeCreationOptions

    model = TestUtils.create_test_model()
    ctx = getcontext(model)

    # Test case 1: check that getifcreated  the variable created by getorcreate
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    @test getifcreated(model, ctx, xref) == xref

    # Test case 2: check that getifcreated returns the variable created by getorcreate in a vector
    y = getorcreate!(model, ctx, NodeCreationOptions(), :y, 1)
    @test getifcreated(model, ctx, y[1]) == y[1]

    # Test case 3: check that getifcreated returns a new variable node when called with integer input
    c = getifcreated(model, ctx, 1)
    @test value(getproperties(model[c])) == 1

    # Test case 4: check that getifcreated returns a new variable node when called with a vector input
    c = getifcreated(model, ctx, [1, 2])
    @test value(getproperties(model[c])) == [1, 2]

    # Test case 5: check that getifcreated returns a tuple of variable nodes when called with a tuple of NodeData
    output = getifcreated(model, ctx, (xref, y[1]))
    @test output == (xref, y[1])

    # Test case 6: check that getifcreated returns a tuple of new variable nodes when called with a tuple of integers
    output = getifcreated(model, ctx, (1, 2))
    @test value(getproperties(model[output[1]])) == 1
    @test value(getproperties(model[output[2]])) == 2

    # Test case 7: check that getifcreated returns a tuple of variable nodes when called with a tuple of mixed input
    output = getifcreated(model, ctx, (xref, 1))
    @test output[1] == xref && value(getproperties(model[output[2]])) == 1

    # Test case 10: check that getifcreated returns the variable node if we create a variable and call it by symbol in a vector
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    zref = getorcreate!(model, ctx, NodeCreationOptions(), :z, 1)
    z_fetched = getifcreated(model, ctx, zref[1])
    @test z_fetched == zref[1]

    # Test case 11: Test that getifcreated returns a constant node when we call it with a symbol
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    zref = getifcreated(model, ctx, :Bernoulli)
    @test value(getproperties(model[zref])) == :Bernoulli

    # Test case 12: Test that getifcreated returns a vector of NodeLabels if called with a vector of NodeLabels
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    y = getorcreate!(model, ctx, NodeCreationOptions(), :y, nothing)
    zref = getifcreated(model, ctx, [xref, y])
    @test zref == [xref, y]

    # Test case 13: Test that getifcreated returns a ResizableArray tensor of NodeLabels if called with a ResizableArray tensor of NodeLabels
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, 1, 1)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, 2, 1)
    zref = getifcreated(model, ctx, xref)
    @test zref == xref

    # Test case 14: Test that getifcreated returns multiple variables if called with a tuple of constants
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    zref = getifcreated(model, ctx, ([1, 1], 2))
    @test nv(model) == 2 && value(getproperties(model[zref[1]])) == [1, 1] && value(getproperties(model[zref[2]])) == 2

    # Test case 15: Test that getifcreated returns a ProxyLabel if called with a ProxyLabel
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    xref = proxylabel(:x, xref, nothing)
    zref = getifcreated(model, ctx, xref)
    @test zref === xref
end

@testitem "make_node!(::Atomic)" setup = [TestUtils] begin
    using Distributions
    using Graphs, BitSetTuples
    import GraphPPL:
        getcontext,
        make_node!,
        create_model,
        getorcreate!,
        AnonymousVariable,
        proxylabel,
        getname,
        label_for,
        edges,
        MixedArguments,
        prune!,
        fform,
        value,
        NodeCreationOptions,
        getproperties

    # Test 1: Deterministic call returns result of deterministic function and does not create new node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = AnonymousVariable(model, ctx)
    @test make_node!(model, ctx, options, +, xref, (1, 1)) == (nothing, 2)
    @test make_node!(model, ctx, options, sin, xref, (0,)) == (nothing, 0)
    @test nv(model) == 0

    xref = proxylabel(:proxy, AnonymousVariable(model, ctx), nothing)
    @test make_node!(model, ctx, options, +, xref, (1, 1)) == (nothing, 2)
    @test make_node!(model, ctx, options, sin, xref, (0,)) == (nothing, 0)
    @test nv(model) == 0

    # Test 2: Stochastic atomic call returns a new node id
    node_id, _ = make_node!(model, ctx, options, Normal, xref, (μ = 0, σ = 1))
    @test nv(model) == 4
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]

    # Test 3: Stochastic atomic call with an AbstractArray as rhs_interfaces
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    make_node!(model, ctx, options, Normal, xref, (0, 1))
    @test nv(model) == 4 && ne(model) == 3

    # Test 4: Deterministic atomic call with nodelabels should create the actual node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    make_node!(model, ctx, options, +, out, (in1, in2))
    @test nv(model) == 4 && ne(model) == 3

    # Test 5: Deterministic atomic call with nodelabels should create the actual node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    make_node!(model, ctx, options, +, out, (in = [in1, in2],))
    @test nv(model) == 4

    # Test 6: Stochastic node with default arguments
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    node_id, _ = make_node!(model, ctx, options, Normal, xref, (0, 1))
    @test nv(model) == 4
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]

    # Test 7: Stochastic node with instantiated object
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    uprior = Normal(0, 1)
    xref = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, uprior, xref, nothing)
    @test nv(model) == 2

    # Test 8: Deterministic node with nodelabel objects where all interfaces are already defined (no missing interfaces)
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    @test_throws "Expected only one missing interface, got () of length 0 (node sum with interfaces (:in, :out))" make_node!(
        model, ctx, options, +, out, (in = in1, out = in2)
    )

    # Test 8: Stochastic node with nodelabel objects where we have an array on the rhs (so should create 1 node for [0, 1])
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    nodeid, _ = make_node!(model, ctx, options, TestUtils.ArbitraryNode, out, (in = [0, 1],))
    @test nv(model) == 3 && value(getproperties(model[ctx[:constvar_2]])) == [0, 1]

    # Test 9: Stochastic node with all interfaces defined as constants
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    nodeid, _ = make_node!(model, ctx, options, TestUtils.ArbitraryNode, out, (1, 1))
    @test nv(model) == 4
    @test getname.(edges(model, nodeid)) == [:out, :in, :in]
    @test getname.(edges(model, nodeid)) == [:out, :in, :in]

    #Test 10: Deterministic node with keyword arguments
    function abc(; a = 1, b = 2)
        return a + b
    end
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = AnonymousVariable(model, ctx)
    @test make_node!(model, ctx, options, abc, out, (a = 1, b = 2)) == (nothing, 3)

    # Test 11: Deterministic node with mixed arguments
    function abc(a; b = 2)
        return a + b
    end
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = AnonymousVariable(model, ctx)
    @test make_node!(model, ctx, options, abc, out, MixedArguments((2,), (b = 2,))) == (nothing, 4)

    # Test 12: Deterministic node with mixed arguments that has to be materialized should throw error
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    a = getorcreate!(model, ctx, :a, nothing)
    @test_throws ErrorException make_node!(model, ctx, options, abc, out, MixedArguments((a,), (b = 2,)))

    # Test 13: Make stochastic node with aliases
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, Normal, xref, (μ = 0, τ = 1))
    @test any((key) -> fform(key) == TestUtils.NormalMeanPrecision, keys(ctx.factor_nodes))
    @test nv(model) == 4

    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, Normal, xref, (μ = 0, σ = 1))
    @test any((key) -> fform(key) == TestUtils.NormalMeanVariance, keys(ctx.factor_nodes))
    @test nv(model) == 4

    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, Normal, xref, (0, 1))
    @test any((key) -> fform(key) == TestUtils.NormalMeanVariance, keys(ctx.factor_nodes))
    @test nv(model) == 4

    # Test 14: Make deterministic node with ProxyLabels as arguments
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    xref = proxylabel(:x, xref, nothing)
    y = getorcreate!(model, ctx, :y, nothing)
    y = proxylabel(:y, y, nothing)
    zref = getorcreate!(model, ctx, :z, nothing)
    node_id = make_node!(model, ctx, options, +, zref, (xref, y))
    prune!(model)
    @test nv(model) == 4

    # Test 15.1: Make stochastic node with aliased interfaces
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    μ = getorcreate!(model, ctx, :μ, nothing)
    σ = getorcreate!(model, ctx, :σ, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    for keys in [(:mean, :variance), (:m, :variance), (:mean, :v)]
        local node_id, _ = make_node!(model, ctx, options, Normal, out, NamedTuple{keys}((μ, σ)))
        @test GraphPPL.fform(GraphPPL.getproperties(model[node_id])) === TestUtils.NormalMeanVariance
        @test GraphPPL.neighbors(model, node_id) == [out, μ, σ]
    end

    # Test 15.2: Make stochastic node with aliased interfaces
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    μ = getorcreate!(model, ctx, :μ, nothing)
    p = getorcreate!(model, ctx, :σ, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    for keys in [(:mean, :precision), (:m, :precision), (:mean, :p)]
        local node_id, _ = make_node!(model, ctx, options, Normal, out, NamedTuple{keys}((μ, p)))
        @test GraphPPL.fform(GraphPPL.getproperties(model[node_id])) === TestUtils.NormalMeanPrecision
        @test GraphPPL.neighbors(model, node_id) == [out, μ, p]
    end
end

@testitem "materialize_factor_node!" setup = [TestUtils] begin
    using Distributions
    using Graphs
    import GraphPPL:
        getcontext,
        materialize_factor_node!,
        create_model,
        getorcreate!,
        getifcreated,
        proxylabel,
        prune!,
        getname,
        label_for,
        edges,
        NodeCreationOptions

    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, options, :x, nothing)
    μref = getifcreated(model, ctx, 0)
    σref = getifcreated(model, ctx, 1)

    # Test 1: Stochastic atomic call returns a new node
    node_id, _, _ = materialize_factor_node!(model, ctx, options, Normal, (out = xref, μ = μref, σ = σref))
    @test nv(model) == 4
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]

    # Test 3: Stochastic atomic call with an AbstractArray as rhs_interfaces
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    μref = getifcreated(model, ctx, 0)
    σref = getifcreated(model, ctx, 1)
    materialize_factor_node!(model, ctx, options, Normal, (out = xref, μ = μref, σ = σref))
    @test nv(model) == 4 && ne(model) == 3

    # Test 4: Deterministic atomic call with nodelabels should create the actual node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    materialize_factor_node!(model, ctx, options, +, (out = out, in = (in1, in2)))
    @test nv(model) == 4 && ne(model) == 3

    # Test 14: Make deterministic node with ProxyLabels as arguments
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    xref = proxylabel(:x, xref, nothing)
    y = getorcreate!(model, ctx, :y, nothing)
    y = proxylabel(:y, y, nothing)
    zref = getorcreate!(model, ctx, :z, nothing)
    node_id = materialize_factor_node!(model, ctx, options, +, (out = zref, in = (xref, y)))
    prune!(model)
    @test nv(model) == 4
end

@testitem "make_node!(::Composite)" setup = [TestUtils] begin
    using MetaGraphsNext, Graphs
    import GraphPPL: getcontext, make_node!, create_model, getorcreate!, proxylabel, NodeCreationOptions

    #test make node for priors
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    make_node!(model, ctx, options, TestUtils.prior, proxylabel(:x, xref, nothing), ())
    @test nv(model) == 4
    @test ctx[TestUtils.prior, 1][:a] == proxylabel(:x, xref, nothing)

    #test make node for other composite models
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    @test_throws ErrorException make_node!(model, ctx, options, TestUtils.gcv, proxylabel(:x, xref, nothing), (0, 1))

    # test make node of broadcastable composite model
    model = create_model(TestUtils.broadcaster())
    @test nv(model) == 103
end

@testitem "broadcast" setup = [TestUtils] begin
    import GraphPPL: NodeLabel, ResizableArray, create_model, getcontext, getorcreate!, make_node!, NodeCreationOptions

    # Test 1: Broadcast a vector node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, 1)
    xref = getorcreate!(model, ctx, :x, 2)
    y = getorcreate!(model, ctx, :y, 1)
    y = getorcreate!(model, ctx, :y, 2)
    zref = getorcreate!(model, ctx, :z, 1)
    zref = getorcreate!(model, ctx, :z, 2)
    zref = broadcast((z_, x_, y_) -> begin
        var = make_node!(model, ctx, options, +, z_, (x_, y_))
    end, zref, xref, y)
    @test size(zref) == (2,)

    # Test 2: Broadcast a matrix node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, 1, 1)
    xref = getorcreate!(model, ctx, :x, 1, 2)
    xref = getorcreate!(model, ctx, :x, 2, 1)
    xref = getorcreate!(model, ctx, :x, 2, 2)

    y = getorcreate!(model, ctx, :y, 1, 1)
    y = getorcreate!(model, ctx, :y, 1, 2)
    y = getorcreate!(model, ctx, :y, 2, 1)
    y = getorcreate!(model, ctx, :y, 2, 2)

    zref = getorcreate!(model, ctx, :z, 1, 1)
    zref = getorcreate!(model, ctx, :z, 1, 2)
    zref = getorcreate!(model, ctx, :z, 2, 1)
    zref = getorcreate!(model, ctx, :z, 2, 2)

    zref = broadcast((z_, x_, y_) -> begin
        var = make_node!(model, ctx, options, +, z_, (x_, y_))
    end, zref, xref, y)
    @test size(zref) == (2, 2)

    # Test 3: Broadcast a vector node with a matrix node
    model = TestUtils.create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, 1)
    xref = getorcreate!(model, ctx, :x, 2)
    y = getorcreate!(model, ctx, :y, 1, 1)
    y = getorcreate!(model, ctx, :y, 1, 2)
    y = getorcreate!(model, ctx, :y, 2, 1)
    y = getorcreate!(model, ctx, :y, 2, 2)

    zref = getorcreate!(model, ctx, :z, 1, 1)
    zref = getorcreate!(model, ctx, :z, 1, 2)
    zref = getorcreate!(model, ctx, :z, 2, 1)
    zref = getorcreate!(model, ctx, :z, 2, 2)

    zref = broadcast((z_, x_, y_) -> begin
        var = make_node!(model, ctx, options, +, z_, (x_, y_))
    end, zref, xref, y)
    @test size(zref) == (2, 2)
end