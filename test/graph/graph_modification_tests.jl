@testitem "setindex!(::Model, ::NodeData, ::NodeLabel)" begin
    using Graphs
    import GraphPPL: getcontext, NodeLabel, NodeData, VariableNodeProperties, FactorNodeProperties

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    model[NodeLabel(:μ, 1)] = NodeData(ctx, VariableNodeProperties(name = :μ, index = nothing))
    @test nv(model) == 1 && ne(model) == 0

    model[NodeLabel(:x, 2)] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    @test nv(model) == 2 && ne(model) == 0

    model[NodeLabel(sum, 3)] = NodeData(ctx, FactorNodeProperties(fform = sum))
    @test nv(model) == 3 && ne(model) == 0

    @test_throws MethodError model[0] = 1
    @test_throws MethodError model["string"] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    @test_throws MethodError model["string"] = NodeData(ctx, FactorNodeProperties(fform = sum))
end

@testitem "setindex!(::Model, ::EdgeLabel, ::NodeLabel, ::NodeLabel)" begin
    using Graphs
    import GraphPPL: getcontext, NodeLabel, NodeData, VariableNodeProperties, EdgeLabel

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)

    μ = NodeLabel(:μ, 1)
    xref = NodeLabel(:x, 2)

    model[μ] = NodeData(ctx, VariableNodeProperties(name = :μ, index = nothing))
    model[xref] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    model[μ, xref] = EdgeLabel(:interface, 1)

    @test ne(model) == 1
    @test_throws MethodError model[0, 1] = 1

    # Test that we can't add an edge between two nodes that don't exist
    model[μ, NodeLabel(:x, 100)] = EdgeLabel(:if, 1)
    @test ne(model) == 1
end

@testitem "add_variable_node!" begin
    import GraphPPL:
        create_model,
        add_variable_node!,
        getcontext,
        options,
        NodeLabel,
        ResizableArray,
        nv,
        ne,
        NodeCreationOptions,
        getproperties,
        is_constant,
        value

    include("testutils.jl")

    # Test 1: simple add variable to model
    model = create_test_model()
    ctx = getcontext(model)
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, nothing)
    @test nv(model) == 1 && haskey(ctx.individual_variables, :x) && ctx.individual_variables[:x] == node_id

    # Test 2: Add second variable to model
    add_variable_node!(model, ctx, NodeCreationOptions(), :y, nothing)
    @test nv(model) == 2 && haskey(ctx, :y)

    # Test 3: Check that adding an integer variable throws a MethodError
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), 1)
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), 1, 1)

    # Test 4: Add a vector variable to the model
    model = create_test_model()
    ctx = getcontext(model)
    ctx[:x] = ResizableArray(NodeLabel, Val(1))
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, 2)
    @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2] == node_id && length(ctx[:x]) == 2

    # Test 5: Add a second vector variable to the model
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, 1)
    @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][1] == node_id && length(ctx[:x]) == 2

    # Test 6: Add a tensor variable to the model
    model = create_test_model()
    ctx = getcontext(model)
    ctx[:x] = ResizableArray(NodeLabel, Val(2))
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, (2, 3))
    @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2, 3] == node_id

    # Test 7: Add a second tensor variable to the model
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, (2, 4))
    @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][2, 4] == node_id

    # Test 9: Add a variable with a non-integer index
    model = create_test_model()
    ctx = getcontext(model)
    ctx[:z] = ResizableArray(NodeLabel, Val(2))
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, "a")
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, ("a", "a"))
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, ("a", 1))
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, (1, "a"))

    # Test 10: Add a variable with a negative index
    ctx[:x] = ResizableArray(NodeLabel, Val(1))
    @test_throws BoundsError add_variable_node!(model, ctx, NodeCreationOptions(), :x, -1)

    # Test 11: Add a variable with options
    model = create_test_model()
    ctx = getcontext(model)
    var = add_variable_node!(model, ctx, NodeCreationOptions(kind = :constant, value = 1.0), :x, nothing)
    @test nv(model) == 1 &&
        haskey(ctx, :x) &&
        ctx[:x] == var &&
        is_constant(getproperties(model[var])) &&
        value(getproperties(model[var])) == 1.0

    # Test 12: Add a variable without options
    model = create_test_model()
    ctx = getcontext(model)
    var = add_variable_node!(model, ctx, :x, nothing)
    @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x] == var
end

@testitem "add_atomic_factor_node!" begin
    using Distributions
    using Graphs
    import GraphPPL: create_model, add_atomic_factor_node!, getorcreate!, getcontext, getorcreate!, label_for, getname, NodeCreationOptions

    include("testutils.jl")

    # Test 1: Add an atomic factor node to the model
    model = create_test_model(plugins = GraphPPL.PluginsCollection(GraphPPL.MetaPlugin()))
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, sum)
    @test model[node_id] === node_data
    @test nv(model) == 2 && getname(label_for(model.graph, 2)) == sum

    # Test 2: Add a second atomic factor node to the model with the same name and assert they are different
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, sum)
    @test model[node_id] === node_data
    @test nv(model) == 3 && getname(label_for(model.graph, 3)) == sum

    # Test 3: Add an atomic factor node with options
    options = NodeCreationOptions((; meta = true,))
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, sum)
    @test model[node_id] === node_data
    @test nv(model) == 4 && getname(label_for(model.graph, 4)) == sum
    @test GraphPPL.hasextra(node_data, :meta)
    @test GraphPPL.getextra(node_data, :meta) == true

    # Test 4: Test that creating a node with an instantiated object is supported
    model = create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    prior = Normal(0, 1)
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, prior)
    @test model[node_id] === node_data
    @test nv(model) == 1 && getname(label_for(model.graph, 1)) == Normal(0, 1)
end

@testitem "add_composite_factor_node!" begin
    using Graphs
    import GraphPPL: create_model, add_composite_factor_node!, getcontext, to_symbol, children, add_variable_node!, Context

    include("testutils.jl")

    # Add a composite factor node to the model
    model = create_test_model()
    parent_ctx = getcontext(model)
    child_ctx = getcontext(model)
    add_variable_node!(model, child_ctx, :x, nothing)
    add_variable_node!(model, child_ctx, :y, nothing)
    node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :f)
    @test nv(model) == 2 &&
        haskey(children(parent_ctx), node_id) &&
        children(parent_ctx)[node_id] === child_ctx &&
        length(child_ctx.individual_variables) == 2

    # Add a composite factor node with a different name
    node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :g)
    @test nv(model) == 2 &&
        haskey(children(parent_ctx), node_id) &&
        children(parent_ctx)[node_id] === child_ctx &&
        length(child_ctx.individual_variables) == 2

    # Add a composite factor node with an empty child context
    empty_ctx = Context()
    node_id = add_composite_factor_node!(model, parent_ctx, empty_ctx, :h)
    @test nv(model) == 2 &&
        haskey(children(parent_ctx), node_id) &&
        children(parent_ctx)[node_id] === empty_ctx &&
        length(empty_ctx.individual_variables) == 0
end

@testitem "add_edge!(::Model, ::NodeLabel, ::NodeLabel, ::Symbol)" begin
    import GraphPPL:
        create_model, getcontext, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!, generate_nodelabel, NodeCreationOptions

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref, xdata, xproperties = GraphPPL.add_atomic_factor_node!(model, ctx, options, sum)
    y = getorcreate!(model, ctx, :y, nothing)

    add_edge!(model, xref, xproperties, y, :interface)

    @test ne(model) == 1

    @test_throws MethodError add_edge!(model, xref, xproperties, y, 123)
end

@testitem "add_edge!(::Model, ::NodeLabel, ::Vector{NodeLabel}, ::Symbol)" begin
    import GraphPPL: create_model, getcontext, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!, NodeCreationOptions

    include("testutils.jl")

    model = create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    y = getorcreate!(model, ctx, :y, nothing)

    variable_nodes = [getorcreate!(model, ctx, i, nothing) for i in [:a, :b, :c]]
    xref, xdata, xproperties = GraphPPL.add_atomic_factor_node!(model, ctx, options, sum)
    add_edge!(model, xref, xproperties, variable_nodes, :interface)

    @test ne(model) == 3 && model[variable_nodes[1], xref] == EdgeLabel(:interface, 1)
end

@testitem "prune!(m::Model)" begin
    using Graphs
    import GraphPPL: create_model, getcontext, getorcreate!, prune!, create_model, getorcreate!, add_edge!, NodeCreationOptions

    include("testutils.jl")

    # Test 1: Prune a node with no edges
    model = create_test_model()
    ctx = getcontext(model)
    xref = getorcreate!(model, ctx, :x, nothing)
    prune!(model)
    @test nv(model) == 0

    # Test 2: Prune two nodes
    model = create_test_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    xref = getorcreate!(model, ctx, :x, nothing)
    y, ydata, yproperties = GraphPPL.add_atomic_factor_node!(model, ctx, options, sum)
    zref = getorcreate!(model, ctx, :z, nothing)
    w = getorcreate!(model, ctx, :w, nothing)

    add_edge!(model, y, yproperties, zref, :test)
    prune!(model)
    @test nv(model) == 2
end