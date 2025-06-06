@testitem "Variable node creation: add_variable_node!" begin
    import GraphPPL:
        BipartiteModel,
        Context,
        create_model,
        get_context,
        add_variable_node!,
        VariableNodeKind,
        nv,
        has_variable,
        get_variable,
        get_variable_data

    model = create_model(BipartiteModel)
    context = get_context(model)

    # (1) Add first individual variable node
    name1 = :x
    initial_node_count = nv(model)

    @test !has_variable(context, name1)  # Should not exist initially

    label1 = add_variable_node!(model, context, name1, nothing, VariableNodeKind.Random, nothing, nothing)

    # Test variable was created in model
    @test label1 !== nothing
    @test label1 <: VariableNodeLabel
    @test nv(model) == initial_node_count + 1

    # Test variable was added to context
    @test has_variable(context, name1)
    @test get_variable(context, name1) == label1

    # Test we can retrieve variable data from model
    var_data1 = get_variable_data(model, label1)
    @test var_data1 !== nothing

    # (2) Add second individual variable with different kind
    name2 = :y
    value2 = 42.0

    @test !has_variable(context, name2)  # Should not exist initially

    label2 = add_variable_node!(model, context, name2, nothing, VariableNodeKind.Constant, nothing, value2)

    # Test second variable was created
    @test label2 !== nothing
    @test label2 != label1  # Should be unique
    @test nv(model) == initial_node_count + 2

    # Test both variables exist in context
    @test has_variable(context, name1)
    @test has_variable(context, name2)
    @test get_variable(context, name1) == label1
    @test get_variable(context, name2) == label2

    # (3) Add indexed variable (vector-like)
    name3 = :z
    index3 = 1

    @test !has_variable(context, name3, index3)  # Should not exist initially

    label3 = add_variable_node!(model, context, name3, index3, VariableNodeKind.Random, nothing, nothing)

    # Test indexed variable was created
    @test label3 !== nothing
    @test label3 != label1 && label3 != label2
    @test nv(model) == initial_node_count + 3

    # Test indexed variable exists in context
    @test has_variable(context, name3, index3)
    @test get_variable(context, name3, index3) == label3

    # Test that individual variables still exist
    @test has_variable(context, name1)
    @test has_variable(context, name2)
    @test get_variable(context, name1) == label1
    @test get_variable(context, name2) == label2
end

@testitem "Variable node creation: getorcreate!" begin
    import GraphPPL: BipartiteModel, Context, create_model, get_context, getorcreate!, nv, has_variable, get_variable

    model = create_model(BipartiteModel)
    context = get_context(model)

    # (1) Create new individual variable
    name1 = :a
    initial_node_count = nv(model)

    @test !has_variable(context, name1)  # Should not exist initially

    var1 = getorcreate!(model, context, name1, nothing)

    # Test variable was created
    @test var1 !== nothing
    @test typeof(var1).name.name == :VariableNodeLabel
    @test nv(model) == initial_node_count + 1
    @test has_variable(context, name1)
    @test get_variable(context, name1) == var1

    # (2) Get existing variable (should not create new one)
    var1_again = getorcreate!(model, context, name1, nothing)

    # Test same variable was returned
    @test var1_again == var1  # Should be identical
    @test nv(model) == initial_node_count + 1  # No new node created
    @test has_variable(context, name1)

    # (3) Create indexed variables
    name2 = :b
    index1 = 1
    index2 = 2

    @test !has_variable(context, name2, index1)
    @test !has_variable(context, name2, index2)

    var2_1 = getorcreate!(model, context, name2, index1)
    var2_2 = getorcreate!(model, context, name2, index2)

    # Test indexed variables were created
    @test var2_1 !== nothing
    @test var2_2 !== nothing
    @test var2_1 != var2_2  # Should be different variables
    @test nv(model) == initial_node_count + 3
    @test has_variable(context, name2, index1)
    @test has_variable(context, name2, index2)
    @test get_variable(context, name2, index1) == var2_1
    @test get_variable(context, name2, index2) == var2_2

    # (4) Get existing indexed variable (should not create new one)
    var2_1_again = getorcreate!(model, context, name2, index1)

    # Test same variable was returned
    @test var2_1_again == var2_1
    @test nv(model) == initial_node_count + 3  # No new node created

    # Test first variable still exists
    @test has_variable(context, name1)
    @test get_variable(context, name1) == var1
end

@testitem "Variable node creation: getorcreate! with ranges" begin
    import GraphPPL: BipartiteModel, Context, create_model, get_context, getorcreate!, nv, has_variable, get_variable

    model = create_model(BipartiteModel)
    context = get_context(model)

    # (1) Create variables with range
    name1 = :vec
    range1 = 1:3
    initial_node_count = nv(model)

    # Test none exist initially
    @test !has_variable(context, name1, 1)
    @test !has_variable(context, name1, 2)
    @test !has_variable(context, name1, 3)

    first_var = getorcreate!(model, context, name1, range1)

    # Test all variables in range were created
    @test first_var !== nothing
    @test nv(model) == initial_node_count + 3  # 3 variables created
    @test has_variable(context, name1, 1)
    @test has_variable(context, name1, 2)
    @test has_variable(context, name1, 3)

    # Test first variable is returned
    @test get_variable(context, name1, 1) == first_var

    # Test all variables are unique
    var1 = get_variable(context, name1, 1)
    var2 = get_variable(context, name1, 2)
    var3 = get_variable(context, name1, 3)
    @test var1 != var2
    @test var2 != var3
    @test var1 != var3

    # (2) Create tensor variables with multiple ranges
    name2 = :tensor
    range2_1 = 1:2
    range2_2 = 1:2

    # Test none exist initially
    @test !has_variable(context, name2, 1, 1)
    @test !has_variable(context, name2, 1, 2)
    @test !has_variable(context, name2, 2, 1)
    @test !has_variable(context, name2, 2, 2)

    first_tensor_var = getorcreate!(model, context, name2, range2_1, range2_2)

    # Test all tensor variables were created (2x2 = 4 variables)
    @test first_tensor_var !== nothing
    @test nv(model) == initial_node_count + 3 + 4  # Previous 3 + new 4
    @test has_variable(context, name2, 1, 1)
    @test has_variable(context, name2, 1, 2)
    @test has_variable(context, name2, 2, 1)
    @test has_variable(context, name2, 2, 2)

    # Test first variable is returned
    @test get_variable(context, name2, 1, 1) == first_tensor_var

    # Test all tensor variables are unique
    tensor_vars = [get_variable(context, name2, i, j) for i in 1:2, j in 1:2]
    @test length(unique(tensor_vars)) == 4  # All should be unique

    # Test vector variables still exist
    @test has_variable(context, name1, 1)
    @test has_variable(context, name1, 2)
    @test has_variable(context, name1, 3)
end

@testitem "Variable node creation: getifcreated" begin
    import GraphPPL: BipartiteModel, Context, create_model, get_context, getifcreated, add_variable_node!, VariableNodeKind, nv, ProxyLabel

    model = create_model(BipartiteModel)
    context = get_context(model)

    # (1) Test with existing VariableNodeLabel (should return as-is)
    name1 = :existing
    existing_label = add_variable_node!(model, context, name1, nothing, VariableNodeKind.Random, nothing, nothing)
    initial_node_count = nv(model)

    result1 = getifcreated(model, context, existing_label)

    # Test existing label is returned unchanged
    @test result1 == existing_label
    @test nv(model) == initial_node_count  # No new nodes created

    # (2) Test with raw value (should create constant node)
    raw_value = 3.14

    result2 = getifcreated(model, context, raw_value)

    # Test constant node was created
    @test result2 !== nothing
    @test typeof(result2).name.name == :VariableNodeLabel
    @test result2 != existing_label  # Should be different
    @test nv(model) == initial_node_count + 1

    # (3) Test with collection of labels (should map over elements)
    name3 = :another
    label3 = add_variable_node!(model, context, name3, nothing, VariableNodeKind.Random, nothing, nothing)

    collection = [existing_label, label3]
    result3 = getifcreated(model, context, collection)

    # Test collection is mapped correctly
    @test typeof(result3) <: AbstractArray
    @test length(result3) == 2
    @test result3[1] == existing_label
    @test result3[2] == label3
    @test nv(model) == initial_node_count + 2  # Only one constant from previous test

    # (4) Test with different raw values (should create multiple constants)
    raw_values = [1, 2, 3]
    current_node_count = nv(model)

    result4 = getifcreated(model, context, raw_values)

    # Test multiple constants were created
    @test typeof(result4) <: AbstractArray
    @test length(result4) == 3
    @test nv(model) == current_node_count + 3  # 3 new constant nodes

    # Test all elements are unique labels
    @test result4[1] != result4[2]
    @test result4[2] != result4[3]
    @test result4[1] != result4[3]
    @test all(r -> typeof(r).name.name == :VariableNodeLabel, result4)

    # Test original variables still exist and unchanged
    @test result1 == existing_label
    @test result3[1] == existing_label
    @test result3[2] == label3
end