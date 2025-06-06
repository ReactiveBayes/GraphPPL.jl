@testitem "Factor node materialization: add_atomic_factor_node!" begin
    import GraphPPL:
        BipartiteModel,
        Context,
        create_model,
        get_context,
        add_atomic_factor_node!,
        EmptyFactorNodeCreationOptions,
        nv,
        has_factor,
        get_factor,
        get_factors,
        get_factor_data

    model = create_model(BipartiteModel)
    context = get_context(model)
    options = EmptyFactorNodeCreationOptions

    # (1) Add first factor node with sum functional form
    fform1 = sum
    initial_node_count = nv(model)

    @test !has_factor(context, fform1)  # Should not exist initially

    label1, nodedata1 = add_atomic_factor_node!(model, context, options, fform1)

    # Test return values are valid
    @test label1 !== nothing
    @test label1 isa FactorNodeLabel
    @test nodedata1 !== nothing

    # Test model node count increased by 1
    @test nv(model) == initial_node_count + 1

    # Test context now has this factor type
    @test has_factor(context, fform1)
    @test length(get_factor(context, fform1)) == 1
    @test get_factor(context, fform1)[1] == label1

    # Test we can retrieve factor data from model
    retrieved_data1 = get_factor_data(model, label1)
    @test typeof(retrieved_data1) == typeof(nodedata1)

    # (2) Add second factor node with same functional form (sum)
    label2, nodedata2 = add_atomic_factor_node!(model, context, options, fform1)

    # Test labels are unique
    @test label2 != label1

    # Test model node count increased by 1 again
    @test nv(model) == initial_node_count + 2

    # Test context now has 2 factors of this type
    @test has_factor(context, fform1)
    @test length(get_factor(context, fform1)) == 2
    @test label1 in get_factor(context, fform1)
    @test label2 in get_factor(context, fform1)

    # (3) Add third factor node with different functional form
    fform2 = prod
    @test !has_factor(context, fform2)  # Should not exist initially

    label3, nodedata3 = add_atomic_factor_node!(model, context, options, fform2)

    # Test model node count increased by 1 again
    @test nv(model) == initial_node_count + 3

    # Test old results for fform1 stay the same
    @test length(get_factor(context, fform1)) == 2
    @test label1 in get_factor(context, fform1)
    @test label2 in get_factor(context, fform1)

    # Test context has new field with new functional form
    @test has_factor(context, fform2)
    @test length(get_factor(context, fform2)) == 1
    @test get_factor(context, fform2)[1] == label3

    # Test all factors are in the model
    all_factors = collect(get_factors(model))
    @test length(all_factors) == 3
    @test label1 in all_factors
    @test label2 in all_factors
    @test label3 in all_factors
end

@testitem "Factor node materialization: add_edge!" begin
    import GraphPPL:
        BipartiteModel,
        Context,
        create_model,
        get_context,
        add_atomic_factor_node!,
        EmptyFactorNodeCreationOptions,
        add_variable!,
        create_variable_data,
        add_edge!,
        create_edge_data,
        has_edge,
        get_edge_data,
        ne

    model = create_model(BipartiteModel)
    context = get_context(model)
    options = EmptyFactorNodeCreationOptions

    # Create variables and factors for testing edges
    var_data1 = create_variable_data(model, :x, 1)
    var_label1 = add_variable!(model, var_data1)
    var_data2 = create_variable_data(model, :y, 2)
    var_label2 = add_variable!(model, var_data2)

    factor_label1, _ = add_atomic_factor_node!(model, context, options, sum)
    factor_label2, _ = add_atomic_factor_node!(model, context, options, prod)

    # (1) Add first edge between var1 and factor1
    initial_edge_count = ne(model)
    @test !has_edge(model, var_label1, factor_label1)  # Should not exist initially

    edge_data1 = create_edge_data(model, :input1, 1)
    edge_added = add_edge!(model, factor_label1, var_label1, :input1, 1)
    @test_throws ErrorException add_edge!(model, factor_label1, var_label1, :input1, 1) # Should throw error because edge already exists

    # Test edge was successfully added
    @test edge_added == true
    @test ne(model) == initial_edge_count + 1
    @test has_edge(model, var_label1, factor_label1)

    # Test we can retrieve edge data
    retrieved_edge_data1 = get_edge_data(model, var_label1, factor_label1)
    @test typeof(retrieved_edge_data1) == typeof(edge_data1)

    # (2) Add second edge from same variable to different factor
    @test !has_edge(model, var_label1, factor_label2)  # Should not exist initially

    edge_data2 = create_edge_data(model, :input2, 1)
    edge_added2 = add_edge!(model, factor_label2, var_label1, :input2, 1)

    # Test second edge was added successfully  
    @test edge_added2 == true
    @test ne(model) == initial_edge_count + 2
    @test has_edge(model, var_label1, factor_label2)

    # Test first edge still exists
    @test has_edge(model, var_label1, factor_label1)

    # Test we can retrieve both edge data
    retrieved_edge_data2 = get_edge_data(model, var_label1, factor_label2)
    @test typeof(retrieved_edge_data2) == typeof(edge_data2)

    # (3) Add third edge from different variable to existing factor
    @test !has_edge(model, var_label2, factor_label1)  # Should not exist initially

    edge_data3 = create_edge_data(model, :input3, 2)
    edge_added3 = add_edge!(model, factor_label1, var_label2, :input3, 2)

    # Test third edge was added successfully
    @test edge_added3 == true
    @test ne(model) == initial_edge_count + 3
    @test has_edge(model, var_label2, factor_label1)

    # Test all previous edges still exist
    @test has_edge(model, var_label1, factor_label1)
    @test has_edge(model, var_label1, factor_label2)

    # Test we can retrieve all edge data independently
    retrieved_edge_data3 = get_edge_data(model, var_label2, factor_label1)
    @test typeof(retrieved_edge_data3) == typeof(edge_data3)

    # Verify edge data is independent (not shared references)
    @test retrieved_edge_data1 !== retrieved_edge_data2
    @test retrieved_edge_data2 !== retrieved_edge_data3
    @test retrieved_edge_data1 !== retrieved_edge_data3
end

@testitem "Factor node materialization: materialize_factor_node!" begin
    import GraphPPL:
        BipartiteModel,
        Context,
        create_model,
        get_context,
        materialize_factor_node!,
        EmptyFactorNodeCreationOptions,
        add_variable!,
        create_variable_data,
        nv,
        ne,
        has_edge,
        get_edge_data,
        has_factor,
        get_factor,
        get_factor_data

    model = create_model(BipartiteModel)
    context = get_context(model)
    options = EmptyFactorNodeCreationOptions

    # Create variables for testing
    var_data1 = create_variable_data(model, :x, 1)
    var_label1 = add_variable!(model, var_data1)
    var_data2 = create_variable_data(model, :y, 2)
    var_label2 = add_variable!(model, var_data2)
    var_data3 = create_variable_data(model, :z, 3)
    var_label3 = add_variable!(model, var_data3)

    # (1) Materialize factor node with single interface
    fform1 = sum
    interfaces1 = (input = var_label1,)
    initial_node_count = nv(model)
    initial_edge_count = ne(model)

    @test !has_factor(context, fform1)  # Should not exist initially

    factor_label1, factor_data1 = materialize_factor_node!(model, context, options, fform1, interfaces1)

    # Test factor node was created
    @test factor_label1 !== nothing
    @test typeof(factor_label1).name.name == :FactorNodeLabel
    @test factor_data1 !== nothing
    @test nv(model) == initial_node_count + 1
    @test has_factor(context, fform1)
    @test get_factor(context, fform1)[1] == factor_label1

    # Test edge was created
    @test ne(model) == initial_edge_count + 1
    @test has_edge(model, var_label1, factor_label1)

    # Test we can retrieve both factor and edge data
    retrieved_factor_data1 = get_factor_data(model, factor_label1)
    @test typeof(retrieved_factor_data1) == typeof(factor_data1)
    edge_data1 = get_edge_data(model, var_label1, factor_label1)
    @test edge_data1 !== nothing

    # (2) Materialize factor node with multiple interfaces  
    fform2 = prod
    interfaces2 = (left = var_label2, right = var_label3)

    @test !has_factor(context, fform2)  # Should not exist initially

    factor_label2, factor_data2 = materialize_factor_node!(model, context, options, fform2, interfaces2)

    # Test factor node was created
    @test factor_label2 !== nothing
    @test factor_label2 != factor_label1  # Should be unique
    @test nv(model) == initial_node_count + 2
    @test has_factor(context, fform2)
    @test get_factor(context, fform2)[1] == factor_label2

    # Test multiple edges were created
    @test ne(model) == initial_edge_count + 3  # 1 from first + 2 from second
    @test has_edge(model, var_label2, factor_label2)
    @test has_edge(model, var_label3, factor_label2)

    # Test first factor and its edge still exist
    @test has_factor(context, fform1)
    @test has_edge(model, var_label1, factor_label1)

    # (3) Materialize another factor with same functional form but different interfaces
    interfaces3 = (value = var_label1,)  # Reuse var_label1 but with different interface name

    factor_label3, factor_data3 = materialize_factor_node!(model, context, options, fform1, interfaces3)

    # Test new factor was created with same functional form
    @test factor_label3 !== nothing
    @test factor_label3 != factor_label1
    @test factor_label3 != factor_label2
    @test nv(model) == initial_node_count + 3

    # Test context now has 2 factors of fform1 type
    @test length(get_factor(context, fform1)) == 2
    @test factor_label1 in get_factor(context, fform1)
    @test factor_label3 in get_factor(context, fform1)

    # Test new edge was created
    @test ne(model) == initial_edge_count + 4  # 1 + 2 + 1
    @test has_edge(model, var_label1, factor_label3)

    # Test all previous connections still exist
    @test has_edge(model, var_label1, factor_label1)
    @test has_edge(model, var_label2, factor_label2)
    @test has_edge(model, var_label3, factor_label2)

    # Test edge data can be retrieved for all connections
    edge_data1_new = get_edge_data(model, var_label1, factor_label1)
    edge_data2_left = get_edge_data(model, var_label2, factor_label2)
    edge_data2_right = get_edge_data(model, var_label3, factor_label2)
    edge_data3_new = get_edge_data(model, var_label1, factor_label3)

    # All edge data should be independent
    @test edge_data1_new !== edge_data2_left
    @test edge_data1_new !== edge_data2_right
    @test edge_data1_new !== edge_data3_new
    @test edge_data2_left !== edge_data2_right
end

@testitem "Factor node materialization: plugin interface" setup = [MockPluginModule] begin
    import GraphPPL:
        BipartiteModel,
        Context,
        create_model,
        get_context,
        add_atomic_factor_node!,
        EmptyFactorNodeCreationOptions,
        nv,
        has_factor,
        get_factor,
        get_factors,
        get_factor_data,
        PluginsCollection

    model = create_model(BipartiteModel, plugins = PluginsCollection((MockPluginModule.MockPlugin(),)))
    context = get_context(model)
    options = EmptyFactorNodeCreationOptions

    # (1) Add first factor node with sum functional form
    fform1 = sum

    label1, nodedata1 = add_atomic_factor_node!(model, context, options, fform1)
    @test GraphPPL.get_extra(nodedata1, :mock_plugin) == true
end