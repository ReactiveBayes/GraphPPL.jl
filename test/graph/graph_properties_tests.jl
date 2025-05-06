@testitem "degree" begin
    import GraphPPL: create_model, getcontext, getorcreate!, NodeCreationOptions, make_node!, degree

    include("testutils.jl")

    for n in 5:10
        model = create_test_model()
        ctx = getcontext(model)

        unused = getorcreate!(model, ctx, :unusued, nothing)
        xref = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)

        foreach(1:n) do k
            getorcreate!(model, ctx, :z, k)
        end

        zref = getorcreate!(model, ctx, :z, 1)

        @test degree(model, unused) === 0
        @test degree(model, xref) === 0
        @test degree(model, y) === 0
        @test all(zᵢ -> degree(model, zᵢ) === 0, zref)

        for i in 1:n
            make_node!(model, ctx, NodeCreationOptions(), sum, y, (in = [xref, zref[i]],))
        end

        @test degree(model, unused) === 0
        @test degree(model, xref) === n
        @test degree(model, y) === n
        @test all(zᵢ -> degree(model, zᵢ) === 1, zref)
    end
end

@testitem "nv_ne(::Model)" begin
    import GraphPPL: create_model, getcontext, nv, ne, NodeData, VariableNodeProperties, NodeLabel, EdgeLabel

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    @test isempty(model)
    @test nv(model) == 0
    @test ne(model) == 0

    model[NodeLabel(:a, 1)] = NodeData(ctx, VariableNodeProperties(name = :a, index = nothing))
    model[NodeLabel(:b, 2)] = NodeData(ctx, VariableNodeProperties(name = :b, index = nothing))
    @test !isempty(model)
    @test nv(model) == 2
    @test ne(model) == 0

    model[NodeLabel(:a, 1), NodeLabel(:b, 2)] = EdgeLabel(:edge, 1)
    @test !isempty(model)
    @test nv(model) == 2
    @test ne(model) == 1
end

@testitem "edges" begin
    import GraphPPL:
        edges,
        create_model,
        getcontext,
        getproperties,
        NodeData,
        VariableNodeProperties,
        FactorNodeProperties,
        NodeLabel,
        EdgeLabel,
        getname,
        add_edge!,
        has_edge,
        getproperties

    include("testutils.jl")

    # Test 1: Test getting all edges from a model
    model = create_test_model()
    ctx = getcontext(model)
    a = NodeLabel(:a, 1)
    b = NodeLabel(:b, 2)
    model[a] = NodeData(ctx, VariableNodeProperties(name = :a, index = nothing))
    model[b] = NodeData(ctx, FactorNodeProperties(fform = sum))
    @test !has_edge(model, a, b)
    @test !has_edge(model, b, a)
    add_edge!(model, b, getproperties(model[b]), a, :edge, 1)
    @test has_edge(model, a, b)
    @test has_edge(model, b, a)
    @test length(edges(model)) == 1

    c = NodeLabel(:c, 2)
    model[c] = NodeData(ctx, FactorNodeProperties(fform = sum))
    @test !has_edge(model, a, c)
    @test !has_edge(model, c, a)
    add_edge!(model, c, getproperties(model[c]), a, :edge, 2)
    @test has_edge(model, a, c)
    @test has_edge(model, c, a)

    @test length(edges(model)) == 2

    # Test 2: Test getting all edges from a model with a specific node
    @test getname.(edges(model, a)) == [:edge, :edge]
    @test getname.(edges(model, b)) == [:edge]
    @test getname.(edges(model, c)) == [:edge]
    # @test getname.(edges(model, [a, b])) == [:edge, :edge, :edge]
end

@testitem "neighbors(::Model, ::NodeData)" begin
    import GraphPPL:
        create_model,
        getcontext,
        neighbors,
        NodeData,
        VariableNodeProperties,
        FactorNodeProperties,
        NodeLabel,
        EdgeLabel,
        getname,
        ResizableArray,
        add_edge!,
        getproperties

    include("testutils.jl")

    using .TestUtils.ModelZoo

    model = create_test_model()
    ctx = getcontext(model)

    a = NodeLabel(:a, 1)
    b = NodeLabel(:b, 2)
    model[a] = NodeData(ctx, FactorNodeProperties(fform = sum))
    model[b] = NodeData(ctx, VariableNodeProperties(name = :b, index = nothing))
    add_edge!(model, a, getproperties(model[a]), b, :edge, 1)
    @test collect(neighbors(model, NodeLabel(:a, 1))) == [NodeLabel(:b, 2)]

    model = create_test_model()
    ctx = getcontext(model)
    a = ResizableArray(NodeLabel, Val(1))
    b = ResizableArray(NodeLabel, Val(1))
    for i in 1:3
        a[i] = NodeLabel(:a, i)
        model[a[i]] = NodeData(ctx, FactorNodeProperties(fform = sum))
        b[i] = NodeLabel(:b, i)
        model[b[i]] = NodeData(ctx, VariableNodeProperties(name = :b, index = i))
        add_edge!(model, a[i], getproperties(model[a[i]]), b[i], :edge, i)
    end
    for n in b
        @test n ∈ neighbors(model, a)
    end
    # Test 2: Test getting sorted neighbors
    model = create_model(simple_model())
    ctx = getcontext(model)
    node = first(neighbors(model, ctx[:z])) # Normal node we're investigating is the only neighbor of `z` in the graph.
    @test getname.(neighbors(model, node)) == [:z, :x, :y]

    # Test 3: Test getting sorted neighbors when one of the edge indices is nothing
    model = create_model(vector_model())
    ctx = getcontext(model)
    node = first(neighbors(model, ctx[:z][1]))
    @test getname.(collect(neighbors(model, node))) == [:z, :x, :y]
end

@testitem "save and load graph" begin
    import GraphPPL: create_model, with_plugins, savegraph, loadgraph, getextra, as_node

    include("testutils.jl")

    using .TestUtils.ModelZoo

    model = create_model(with_plugins(vector_model(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    mktemp() do file, io
        file = file * ".jld2"
        savegraph(file, model)
        model2 = loadgraph(file, GraphPPL.Model)
        for (node, node2) in zip(filter(as_node(), model), filter(as_node(), model2))
            @test node == node2
            @test GraphPPL.getextra(model[node], :factorization_constraint_bitset) ==
                GraphPPL.getextra(model2[node2], :factorization_constraint_bitset)
        end
    end
end