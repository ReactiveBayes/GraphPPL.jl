@testitem "Compact graph metadata and ordered connectivity" begin
    include("testutils.jl")
    import GraphPPL: CompactGraphPlugin, CompactGraph, CompactExtraColumns, CompactNodeExtras
    import GraphPPL: NodeLabel, EdgeLabel, NodeData, VariableNodeProperties, FactorNodeProperties

    columns = CompactExtraColumns()
    a, b = CompactNodeExtras(columns, 1), CompactNodeExtras(columns, 100)
    @test isempty(a)
    GraphPPL.insert!(b, :value, nothing)
    @test haskey(b, :value)
    @test b[:value] === nothing
    @test !haskey(a, :value)
    @test_throws KeyError a[:value]
    GraphPPL.insert!(a, :value, 42)
    @test a[:value] == 42
    @test length(a) == 1
    @test Set(keys(a)) == Set([:value])
    @test_throws ArgumentError GraphPPL.insert!(a, :value, 1)
    GraphPPL.insert!(a, :id, Int32(7))
    @test eltype(columns.columns[:id]) === Int32
    GraphPPL.insert!(b, :id, "extension value")
    @test a[:id] == Int32(7)
    @test b[:id] == "extension value"
    @test !haskey(CompactNodeExtras(columns, 50), :id)
    @test !@inferred(haskey(a, :absent))

    model = create_test_model(plugins = GraphPPL.PluginsCollection(CompactGraphPlugin()))
    @test model.graph isa CompactGraph
    context = GraphPPL.getcontext(model)
    example = GraphPPL.NodeData(context, VariableNodeProperties(name=:example, index=nothing), a)
    @test @inferred(GraphPPL.setextra!(example, GraphPPL.NodeDataExtraKey{:test_flag, Bool}(), true)) === example
    labels = NodeLabel[]
    for i in 1:10
        label = GraphPPL.generate_nodelabel(model, :x)
        node = GraphPPL.new_node_data(model, label, context, VariableNodeProperties(name = :x, index = i))
        GraphPPL.add_vertex!(model, label, node)
        push!(labels, label)
    end
    for i in 2:10
        @test GraphPPL.add_edge!(model, labels[1], labels[i], EdgeLabel(:in, i))
    end
    @test GraphPPL.nv(model) == 10
    @test GraphPPL.ne(model) == 9
    @test collect(GraphPPL.neighbors(model, labels[1])) == labels[2:end]
    @test GraphPPL.degree(model, labels[1]) == 9
    @test !GraphPPL.add_edge!(model, labels[1], labels[2], EdgeLabel(:in, 2))
    @test GraphPPL.has_edge(model, labels[2], labels[1])
    @test !GraphPPL.has_edge(model, labels[2], labels[3])
    @test model[labels[1], labels[4]] == EdgeLabel(:in, 4)
    @test length(collect(GraphPPL.edges(model))) == 9
    @test_throws KeyError model[NodeLabel(:x, 11)]
    @test_throws ArgumentError GraphPPL.prune!(model)
    model[labels[1], labels[2]] = EdgeLabel(:shared, nothing)
    model[labels[1], labels[3]] = EdgeLabel(:shared, nothing)
    @test model[labels[1], labels[2]] === model[labels[1], labels[3]]
    model[labels[1], labels[2]] = EdgeLabel(:changed, nothing)
    @test model[labels[1], labels[3]] == EdgeLabel(:shared, nothing)
end

@testitem "Compact graph model expansion and factorization equivalence" begin
    include("testutils.jl")
    @model function compact_frontend_fixture(n)
        x ~ NormalMeanVariance(0.0, 1.0)
        for i in 1:n
            y[i] ~ NormalMeanVariance(x, 2.0)
        end
    end
    base_plugins = GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())
    standard = GraphPPL.create_model(GraphPPL.with_plugins(compact_frontend_fixture(n = 100), base_plugins))
    compact = GraphPPL.create_model(GraphPPL.with_plugins(compact_frontend_fixture(n = 100), base_plugins + GraphPPL.CompactGraphPlugin()))
    @test GraphPPL.nv(compact) == GraphPPL.nv(standard)
    @test GraphPPL.ne(compact) == GraphPPL.ne(standard)
    @test Set(GraphPPL.labels(compact)) == Set(GraphPPL.labels(standard))
    for label in GraphPPL.labels(standard)
        @test GraphPPL.degree(compact, label) == GraphPPL.degree(standard, label)
        @test Set(GraphPPL.neighbors(compact, label)) == Set(GraphPPL.neighbors(standard, label))
        @test Set(keys(GraphPPL.getextra(compact[label]))) == Set(keys(GraphPPL.getextra(standard[label])))
        if GraphPPL.is_factor(standard[label])
            key = GraphPPL.VariationalConstraintsFactorizationIndicesKey
            @test GraphPPL.getextra(compact[label], key) == map(Tuple, GraphPPL.getextra(standard[label], key))
        end
    end
    @test Base.summarysize(compact) < Base.summarysize(standard)
end
