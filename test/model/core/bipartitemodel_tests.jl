@testitem "BipartiteModel: Variable node operations" begin
    import GraphPPL: BipartiteModel, create_model, get_context, add_variable!, is_variable_node, is_factor_node, get_variable_data, get_variables, make_variable_data, get_factor_data, get_factors, make_factor_data, get_edge_data, has_edge, variable_neighbors,     # Create instance of model
    model = create_model(BipartiteModel)
    context = get_context(model) # Get context after model creation

    # Test adding a single variable node
    var_data = make_variable_data(model_type, context, :test_var, 1)
    var_label = add_variable!(model, var_data)
    @test is_variable_node(model, var_label)
    @test !is_factor_node(model, var_label)

    # Test variable data retrieval
    retrieved_data = get_variable_data(model, var_label)
    @test retrieved_data !== nothing
    @test typeof(retrieved_data) == typeof(var_data)

    # Test adding multiple variable nodes
    var_data2 = make_variable_data(model_type, context, :test_var2, 2)
    var_label2 = add_variable!(model, var_data2)
    @test is_variable_node(model, var_label2)
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
    import GraphPPL: BipartiteModel
    # Create instance of model
    model = create_model(BipartiteModel)
    context = get_context(model)

    # Test adding a single factor node
    factor_data = make_factor_data(model_type, context, TestFactorForm())
    factor_label = add_factor!(model, factor_data)
    @test is_factor_node(model, factor_label)
    @test !is_variable_node(model, factor_label)

    # Test factor data retrieval
    retrieved_data = get_factor_data(model, factor_label)
    @test retrieved_data !== nothing
    @test typeof(retrieved_data) == typeof(factor_data)

    # Test adding multiple factor nodes
    factor_data2 = make_factor_data(model_type, context, TestFactorForm())
    factor_label2 = add_factor!(model, factor_data2)
    @test is_factor_node(model, factor_label2)
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
    import GraphPPL: BipartiteModel
    model = create_model(BipartiteModel)
    context = get_context(model)

    # Add nodes
    var_label1 = add_variable!(model, make_variable_data(model_type, context, :v1, 1))
    var_label2 = add_variable!(model, make_variable_data(model_type, context, :v2, 2))
    factor_label1 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    factor_label2 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))

    # Test edge creation
    edge_data1 = make_edge_data(model_type, :iface1, 1)
    add_edge!(model, var_label1, factor_label1, edge_data1)
    @test has_edge(model, var_label1, factor_label1)
    @test has_edge(model, factor_label1, var_label1) # Test symmetry
    @test ne(model) == 1

    # Test edge data retrieval
    retrieved_edge_data = get_edge_data(model, var_label1, factor_label1)
    @test retrieved_edge_data !== nothing
    @test typeof(retrieved_edge_data) == typeof(edge_data1)

    # Test symmetric edge data retrieval
    retrieved_edge_data_reverse = get_edge_data(model, factor_label1, var_label1)
    @test typeof(retrieved_edge_data_reverse) == typeof(edge_data1)

    # Test multiple edges
    edge_data2 = make_edge_data(model_type, :iface2, 1)
    add_edge!(model, var_label2, factor_label1, edge_data2)
    @test has_edge(model, var_label2, factor_label1)
    @test ne(model) == 2

    edge_data3 = make_edge_data(model_type, :iface3, 1)
    add_edge!(model, var_label1, factor_label2, edge_data3)
    @test has_edge(model, var_label1, factor_label2)
    @test ne(model) == 3
end

@testitem "BipartiteModel: Neighbor operations" begin
    model = create_model(BipartiteModel)
    context = get_context(model)

    # Create a star-like structure with one factor connected to multiple variables
    var_label1 = add_variable!(model, make_variable_data(model_type, context, :v1, 1))
    var_label2 = add_variable!(model, make_variable_data(model_type, context, :v2, 2))
    var_label3 = add_variable!(model, make_variable_data(model_type, context, :v3, 3))
    factor_label = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))

    # Connect all variables to the factor
    add_edge!(model, var_label1, factor_label, make_edge_data(model_type, :v1_to_f, 1))
    add_edge!(model, var_label2, factor_label, make_edge_data(model_type, :v2_to_f, 1))
    add_edge!(model, var_label3, factor_label, make_edge_data(model_type, :v3_to_f, 1))

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
    factor_label2 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    factor_label3 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    var_label4 = add_variable!(model, make_variable_data(model_type, context, :v4, 4))

    # Connect the variable to all factors
    add_edge!(model, var_label4, factor_label, make_edge_data(model_type, :v4_to_f, 1))
    add_edge!(model, var_label4, factor_label2, make_edge_data(model_type, :v4_to_f2, 1))
    add_edge!(model, var_label4, factor_label3, make_edge_data(model_type, :v4_to_f3, 1))

    # Test factor neighbors of variable
    factor_neighbors4 = factor_neighbors(model, var_label4)
    @test length(factor_neighbors4) == 3
    @test factor_label in factor_neighbors4
    @test factor_label2 in factor_neighbors4
    @test factor_label3 in factor_neighbors4

    # Test variables with no neighbors
    var_label5 = add_variable!(model, make_variable_data(model_type, context, :v5, 5))
    factor_neighbors5 = factor_neighbors(model, var_label5)
    @test isempty(factor_neighbors5)

    # Test factors with no neighbors
    factor_label4 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    var_neighbors4 = variable_neighbors(model, factor_label4)
    @test isempty(var_neighbors4)
end

@testitem "BipartiteModel: Model pruning" begin
    import GraphPPL: BipartiteModel
    model = create_model(BipartiteModel)
    context = get_context(model)

    # Create a mix of connected and isolated nodes
    var_label1 = add_variable!(model, make_variable_data(model_type, context, :v1, 1))
    var_label2 = add_variable!(model, make_variable_data(model_type, context, :v2, 2))
    var_label3 = add_variable!(model, make_variable_data(model_type, context, :v3_isolated, 3)) # Will be isolated

    factor_label1 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    factor_label2 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    factor_label3 = add_factor!(model, make_factor_data(model_type, context, TestFactorForm())) # Will be isolated

    # Connect some nodes
    add_edge!(model, var_label1, factor_label1, make_edge_data(model_type, :v1_f1_edge, 1))
    add_edge!(model, var_label2, factor_label2, make_edge_data(model_type, :v2_f2_edge, 1))

    # Initial state verification
    @test nv(model) == 6
    @test ne(model) == 2

    # Test pruning
    prune_model!(model)

    variables = get_variables(model)
    factors = get_factors(model)

    @test nv(model) == 4
    @test ne(model) == 2

    @test length(variables) <= 2
    @test length(factors) <= 2

    @test has_edge(model, var_label1, factor_label1)
    @test has_edge(model, var_label2, factor_label2)
end

@testitem "BipartiteModel: Model metadata" begin
    import GraphPPL: BipartiteModel
    model = create_model(BipartiteModel)

    backend = get_backend(model)
    @test backend !== nothing

    plugins = get_plugins(model)
    @test plugins !== nothing

    source = get_source(model)

    if applicable(get_context, model)
        context_val = get_context(model)
        @test context_val !== nothing
    end
end

@testitem "BipartiteModel: Model save and load" begin
    import GraphPPL: BipartiteModel
    model = create_model(BipartiteModel)
    context = get_context(model)

    var_label = add_variable!(model, make_variable_data(model_type, context, :v_saveload, 1))
    factor_label = add_factor!(model, make_factor_data(model_type, context, TestFactorForm()))
    add_edge!(model, var_label, factor_label, make_edge_data(model_type, :saveload_edge, 1))

    temp_file = tempname()

    try
        save_model(temp_file, model)
        @test isfile(temp_file)

        loaded_model = load_model(temp_file, model_type)

        @test nv(loaded_model) == nv(model)
        @test ne(loaded_model) == ne(model)

        loaded_vars = get_variables(loaded_model)
        loaded_factors = get_factors(loaded_model)

        @test length(loaded_vars) == length(get_variables(model))
        @test length(loaded_factors) == length(get_factors(model))
    finally
        isfile(temp_file) && rm(temp_file)
    end
end
