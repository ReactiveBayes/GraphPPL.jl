@testitem "BipartiteModel: Variable node operations" begin
    import GraphPPL: BipartiteModel, create_model, get_context, add_variable!, get_variable_data, get_variables, create_variable_data, nv

    model = create_model(BipartiteModel)
    context = get_context(model)

    # Test adding a single variable node
    var_data = create_variable_data(model, :test_var, 1)
    var_label = add_variable!(model, var_data)

    # Test variable data retrieval
    retrieved_data = get_variable_data(model, var_label)
    @test retrieved_data !== nothing
    @test typeof(retrieved_data) == typeof(var_data)

    # Test adding multiple variable nodes
    var_data2 = create_variable_data(model, :test_var2, 2)
    var_label2 = add_variable!(model, var_data2)
    @test var_label != var_label2

    # Test getting all variables
    variables = get_variables(model)
    @test length(variables) == 2
    @test var_label in variables
    @test var_label2 in variables

    # Test variable node count
    @test nv(model) == 2
end

@testitem "BipartiteModel: Factor node operations" begin
    import GraphPPL: BipartiteModel, create_model, get_context, add_factor!, get_factor_data, get_factors, create_factor_data, nv

    # Create instance of model
    model = create_model(BipartiteModel)
    context = get_context(model)

    # Test adding a single factor node
    factor_data = create_factor_data(model, sum)
    factor_label = add_factor!(model, factor_data)

    # Test factor data retrieval
    retrieved_data = get_factor_data(model, factor_label)
    @test retrieved_data !== nothing
    @test typeof(retrieved_data) == typeof(factor_data)

    # Test adding multiple factor nodes
    factor_data2 = create_factor_data(model, +)
    factor_label2 = add_factor!(model, factor_data2)
    @test factor_label != factor_label2

    # Test getting all factors
    factors = get_factors(model)
    @test length(factors) == 2
    @test factor_label in factors
    @test factor_label2 in factors

    # Test factor node count
    @test nv(model) == 2
end

@testitem "BipartiteModel: Edge operations" begin
    import GraphPPL:
        BipartiteModel,
        create_model,
        get_context,
        add_variable!,
        add_factor!,
        add_edge!,
        has_edge,
        get_edge_data,
        create_variable_data,
        create_factor_data,
        create_edge_data,
        ne

    model = create_model(BipartiteModel)
    context = get_context(model)

    # Add nodes
    var_data1 = create_variable_data(model, :v1, 1)
    var_label1 = add_variable!(model, var_data1)
    var_data2 = create_variable_data(model, :v2, 2)
    var_label2 = add_variable!(model, var_data2)

    factor_data1 = create_factor_data(model, sum)
    factor_label1 = add_factor!(model, factor_data1)
    factor_data2 = create_factor_data(model, +)
    factor_label2 = add_factor!(model, factor_data2)

    # Test edge creation
    edge_data1 = create_edge_data(model, :iface1, 1)
    add_edge!(model, var_label1, factor_label1, edge_data1)
    @test has_edge(model, var_label1, factor_label1)
    @test ne(model) == 1

    # Test edge data retrieval
    retrieved_edge_data = get_edge_data(model, var_label1, factor_label1)
    @test retrieved_edge_data !== nothing
    @test typeof(retrieved_edge_data) == typeof(edge_data1)

    # Test multiple edges
    edge_data2 = create_edge_data(model, :iface2, 1)
    add_edge!(model, var_label2, factor_label1, edge_data2)
    @test has_edge(model, var_label2, factor_label1)
    @test ne(model) == 2

    edge_data3 = create_edge_data(model, :iface3, 1)
    add_edge!(model, var_label1, factor_label2, edge_data3)
    @test has_edge(model, var_label1, factor_label2)
    @test ne(model) == 3
end

@testitem "BipartiteModel: Neighbor operations" begin
    import GraphPPL:
        BipartiteModel,
        create_model,
        get_context,
        add_variable!,
        add_factor!,
        add_edge!,
        variable_neighbors,
        factor_neighbors,
        create_variable_data,
        create_factor_data,
        create_edge_data

    model = create_model(BipartiteModel)
    context = get_context(model)

    # Create a star-like structure with one factor connected to multiple variables
    var_data1 = create_variable_data(model, :v1, 1)
    var_label1 = add_variable!(model, var_data1)
    var_data2 = create_variable_data(model, :v2, 2)
    var_label2 = add_variable!(model, var_data2)
    var_data3 = create_variable_data(model, :v3, 3)
    var_label3 = add_variable!(model, var_data3)

    factor_data = create_factor_data(model, sum)
    factor_label = add_factor!(model, factor_data)

    # Connect all variables to the factor
    add_edge!(model, var_label1, factor_label, create_edge_data(model, :v1_to_f, 1))
    add_edge!(model, var_label2, factor_label, create_edge_data(model, :v2_to_f, 2))
    add_edge!(model, var_label3, factor_label, create_edge_data(model, :v3_to_f, 3))

    # Test variable neighbors of factor
    var_neighbors = variable_neighbors(model, factor_label)
    @test length(var_neighbors) == 3
    @test var_label1 in var_neighbors
    @test var_label2 in var_neighbors
    @test var_label3 in var_neighbors

    # Test factor neighbors of variables
    factor_neighbors1 = factor_neighbors(model, var_label1)
    @test length(factor_neighbors1) == 1
    @test factor_label in factor_neighbors1

    # Create a second structure with one variable connected to multiple factors
    factor_data2 = create_factor_data(model, +)
    factor_label2 = add_factor!(model, factor_data2)
    factor_data3 = create_factor_data(model, *)
    factor_label3 = add_factor!(model, factor_data3)
    var_data4 = create_variable_data(model, :v4, 4)
    var_label4 = add_variable!(model, var_data4)

    # Connect the variable to all factors
    add_edge!(model, var_label4, factor_label, create_edge_data(model, :v4_to_f, 4))
    add_edge!(model, var_label4, factor_label2, create_edge_data(model, :v4_to_f2, 4))
    add_edge!(model, var_label4, factor_label3, create_edge_data(model, :v4_to_f3, 4))

    # Test factor neighbors of variable
    factor_neighbors4 = factor_neighbors(model, var_label4)
    @test length(factor_neighbors4) == 3
    @test factor_label in factor_neighbors4
    @test factor_label2 in factor_neighbors4
    @test factor_label3 in factor_neighbors4

    # Test variables with no neighbors
    var_data5 = create_variable_data(model, :v5, 5)
    var_label5 = add_variable!(model, var_data5)
    factor_neighbors5 = factor_neighbors(model, var_label5)
    @test isempty(factor_neighbors5)

    # Test factors with no neighbors
    factor_data4 = create_factor_data(model, -)
    factor_label4 = add_factor!(model, factor_data4)
    var_neighbors4 = variable_neighbors(model, factor_label4)
    @test isempty(var_neighbors4)
end

@testitem "BipartiteModel: Model metadata" begin
    import GraphPPL: BipartiteModel, create_model, get_plugins, get_source_code, get_context, get_node_strategy

    model = create_model(BipartiteModel)

    # Test plugins
    plugins = get_plugins(model)
    # Note: plugins can be nothing for BipartiteModel

    # Test source code
    source = get_source_code(model)
    # Note: source can be nothing for BipartiteModel

    # Test context
    context_val = get_context(model)
    @test context_val !== nothing

    # Test node strategy
    strategy = get_node_strategy(model)
    # Note: strategy can be nothing for BipartiteModel
end

@testitem "BipartiteModel: Data type methods" begin
    import GraphPPL: BipartiteModel, create_model, get_variable_data_type, get_factor_data_type, get_edge_data_type

    model = create_model(BipartiteModel)

    # Test data type accessors
    var_type = get_variable_data_type(model)
    @test var_type !== nothing

    factor_type = get_factor_data_type(model)
    @test factor_type !== nothing

    edge_type = get_edge_data_type(model)
    @test edge_type !== nothing
end

@testitem "BipartiteModel: Basic save and load functionality" begin
    import GraphPPL:
        BipartiteModel,
        create_model,
        add_variable!,
        add_factor!,
        add_edge!,
        save_model,
        load_model,
        create_variable_data,
        create_factor_data,
        create_edge_data,
        nv,
        ne

    # Create a simple model
    original_model = create_model(BipartiteModel)

    var_data = create_variable_data(original_model, :test_var, 42)
    var_label = add_variable!(original_model, var_data)

    factor_data = create_factor_data(original_model, sum)
    factor_label = add_factor!(original_model, factor_data)

    edge_data = create_edge_data(original_model, :test_edge, 123)
    add_edge!(original_model, var_label, factor_label, edge_data)

    temp_file = tempname()

    try
        # Test save and load
        save_model(temp_file, original_model)
        @test isfile(temp_file)

        loaded_model = load_model(temp_file, BipartiteModel)
        @test loaded_model !== nothing
        @test nv(loaded_model) == nv(original_model)
        @test ne(loaded_model) == ne(original_model)
    finally
        isfile(temp_file) && rm(temp_file)
    end
end

@testitem "BipartiteModel: Error handling and edge cases" begin
    import GraphPPL:
        BipartiteModel,
        create_model,
        get_context,
        add_variable!,
        add_factor!,
        add_edge!,
        has_edge,
        get_edge_data,
        get_variable_data,
        get_factor_data,
        create_variable_data,
        create_factor_data,
        create_edge_data,
        VariableNodeLabel,
        FactorNodeLabel

    model = create_model(BipartiteModel)

    # Test with non-existent labels
    fake_var_label = VariableNodeLabel(999999)
    fake_factor_label = FactorNodeLabel(999999)

    # Test getting data for non-existent nodes should throw errors
    @test_throws Exception get_variable_data(model, fake_var_label)
    @test_throws Exception get_factor_data(model, fake_factor_label)

    # Test has_edge with non-existent nodes
    @test !has_edge(model, fake_var_label, fake_factor_label)

    # Test get_edge_data with non-existent edge should throw error
    var_data = create_variable_data(model, :existing_var, 1)
    var_label = add_variable!(model, var_data)
    factor_data = create_factor_data(model, sum)
    factor_label = add_factor!(model, factor_data)

    @test_throws Exception get_edge_data(model, var_label, factor_label)  # No edge exists
end

@testitem "BipartiteModel: Empty model operations" begin
    import GraphPPL: BipartiteModel, create_model, get_variables, get_factors, nv, ne

    model = create_model(BipartiteModel)

    # Test operations on empty model
    @test nv(model) == 0
    @test ne(model) == 0
    @test isempty(get_variables(model))
    @test isempty(get_factors(model))
end

@testitem "BipartiteModel: Iterator behavior and properties" begin
    import GraphPPL:
        BipartiteModel,
        create_model,
        get_variables,
        get_factors,
        add_variable!,
        add_factor!,
        create_variable_data,
        create_factor_data,
        VariableNodeLabel,
        FactorNodeLabel

    model = create_model(BipartiteModel)

    # Add multiple nodes
    var_labels = []
    factor_labels = []

    # Use simple functional forms instead of eval
    functional_forms = [+, -, *, /, sum]

    for i in 1:5
        var_data = create_variable_data(model, Symbol("var_$i"), i)
        push!(var_labels, add_variable!(model, var_data))

        factor_data = create_factor_data(model, functional_forms[i])
        push!(factor_labels, add_factor!(model, factor_data))
    end

    # Test that iterators return correct collections
    variables = collect(get_variables(model))
    factors = collect(get_factors(model))

    @test length(variables) == 5
    @test length(factors) == 5
    @test all(v in variables for v in var_labels)
    @test all(f in factors for f in factor_labels)

    # Test iterator properties
    @test eltype(collect(get_variables(model))) <: VariableNodeLabel
    @test eltype(collect(get_factors(model))) <: FactorNodeLabel
end

@testitem "BipartiteModel: Edge data consistency and symmetry" begin
    import GraphPPL:
        BipartiteModel,
        create_model,
        add_variable!,
        add_factor!,
        add_edge!,
        has_edge,
        get_edge_data,
        create_variable_data,
        create_factor_data,
        create_edge_data,
        get_name,
        get_index

    model = create_model(BipartiteModel)

    var_data = create_variable_data(model, :test_var, 1)
    var_label = add_variable!(model, var_data)
    factor_data = create_factor_data(model, sum)
    factor_label = add_factor!(model, factor_data)

    # Test edge operations
    edge_data = create_edge_data(model, :test_edge, 42)
    result = add_edge!(model, var_label, factor_label, edge_data)
    @test result == true  # add_edge! should return boolean

    # Test edge existence in both directions
    @test has_edge(model, var_label, factor_label)
    # Note: has_edge signature only supports (variable, factor) order according to interface

    # Test edge data retrieval
    retrieved_data = get_edge_data(model, var_label, factor_label)
    @test get_name(retrieved_data) == :test_edge
    @test get_index(retrieved_data) == 42

    # Test duplicate edge addition
    duplicate_result = add_edge!(model, var_label, factor_label, edge_data)
    # Behavior for duplicate edges depends on implementation - just verify it doesn't crash
    @test typeof(duplicate_result) == Bool
end

@testitem "BipartiteModel: Create model with parameters" begin
    import GraphPPL: BipartiteModel, create_model, get_plugins, get_node_strategy, get_source_code

    # Test model creation with different parameters
    model_basic = create_model(BipartiteModel)

    # Test model with explicit nothing parameters
    model_with_nothings = create_model(BipartiteModel, plugins = nothing, node_strategy = nothing, source = nothing)

    # Both should work and have consistent behavior
    @test typeof(model_basic) == typeof(model_with_nothings)

    # Test that metadata accessors work consistently
    @test get_plugins(model_basic) == get_plugins(model_with_nothings)
    @test get_node_strategy(model_basic) == get_node_strategy(model_with_nothings)
    @test get_source_code(model_basic) == get_source_code(model_with_nothings)
end
