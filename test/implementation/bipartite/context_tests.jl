@testitem "Root Context Creation" begin
    import GraphPPL: Context, ContextInterface, create_root_context, get_depth, get_parent, get_children

    # Test root context creation
    root_ctx = create_root_context(Context)
    @test root_ctx isa ContextInterface
    @test get_depth(root_ctx) == 0
    @test get_parent(root_ctx) === nothing
    @test_throws Exception get_children(root_ctx, sin)
end

@testitem "Child Context Creation" begin
    import GraphPPL: VariableNodeLabel, Context, ContextInterface, create_root_context, create_child_context, proxylabel
    import GraphPPL: get_variable, has_variable, get_depth, get_parent, get_functional_form, get_children, has_children

    x = VariableNodeLabel(1)
    y = VariableNodeLabel(2)
    x_proxy = proxylabel(:inputs, x, nothing)
    y_proxy = proxylabel(:inputs, y, 1)
    markov_blanket = (x = x_proxy, y = y_proxy)

    root_ctx = create_root_context(Context)
    child_ctx = create_child_context(root_ctx, sin, markov_blanket)
    @test child_ctx isa ContextInterface
    @test get_depth(child_ctx) == 1
    @test get_parent(child_ctx) === root_ctx
    @test get_children(root_ctx, sin) == [child_ctx]
    @test get_children(root_ctx, sin, 1) == child_ctx
    @test get_functional_form(child_ctx) == sin

    @test has_variable(child_ctx, :x)

    @test get_variable(child_ctx, :x) === x_proxy
    @test get_variable(child_ctx, :x, nothing) === x_proxy
    @test_throws Exception get_variable(child_ctx, :x, 1)
    @test_throws Exception get_variable(child_ctx, :x, 1, 1)

    @test has_variable(child_ctx, :y)
    @test has_variable(child_ctx, :y, nothing)
    @test !has_variable(child_ctx, :y, 1)
    @test !has_variable(child_ctx, :y, 1, 1)

    @test get_variable(child_ctx, :y) === y_proxy
    @test get_variable(child_ctx, :y, nothing) === y_proxy
    @test_throws Exception get_variable(child_ctx, :y, 1)
    @test_throws Exception get_variable(child_ctx, :y, 1, 1)
end

@testitem "Basic Context Properties" begin
    import GraphPPL:
        VariableNodeLabel,
        create_root_context,
        create_child_context,
        get_depth,
        get_functional_form,
        get_prefix,
        get_parent,
        get_short_name,
        get_returnval,
        set_returnval!,
        get_path_to_root,
        get_children,
        has_children,
        proxylabel

    # Create test contexts
    root_ctx = create_root_context(Context)
    interface_var = VariableNodeLabel(1)
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(root_ctx, sin, interfaces)
    grandchild_ctx = create_child_context(child_ctx, cos, interfaces)

    # Test depth hierarchy
    @test get_depth(root_ctx) == 0
    @test get_depth(child_ctx) == 1
    @test get_depth(grandchild_ctx) == 2

    # Test children getters
    @test has_children(root_ctx, sin)
    @test has_children(root_ctx, sin, 1)
    @test !has_children(root_ctx, cos)
    @test !has_children(root_ctx, cos, 1)
    @test get_children(root_ctx, sin) == [child_ctx]
    @test get_children(root_ctx, sin, 1) == child_ctx
    @test_throws Exception get_children(root_ctx, cos)

    @test has_children(child_ctx, cos)
    @test has_children(child_ctx, cos, 1)
    @test !has_children(child_ctx, sin)
    @test !has_children(child_ctx, sin, 1)
    @test get_children(child_ctx, cos) == [grandchild_ctx]
    @test get_children(child_ctx, cos, 1) == grandchild_ctx
    @test_throws Exception get_children(child_ctx, sin)

    # Test functional forms
    @test get_functional_form(child_ctx) == sin
    @test get_functional_form(grandchild_ctx) == cos

    # Test prefix and naming
    @test isempty(get_prefix(root_ctx))
    @test isempty(get_short_name(root_ctx))
    @test !isempty(get_prefix(child_ctx))
    @test !isempty(get_short_name(child_ctx))
    @test !isempty(get_prefix(grandchild_ctx))
    @test !isempty(get_short_name(grandchild_ctx))

    # Test parent relationships
    @test get_parent(root_ctx) === nothing
    @test get_parent(child_ctx) === root_ctx
    @test get_parent(grandchild_ctx) === child_ctx

    # Test path to root
    root_path = get_path_to_root(grandchild_ctx)
    @test length(root_path) == 3
    @test root_path[1] === grandchild_ctx
    @test root_path[2] === child_ctx
    @test root_path[3] === root_ctx

    # Test return value setting and getting
    set_returnval!(child_ctx, 42)
    @test get_returnval(root_ctx) == nothing
    @test get_returnval(child_ctx) == 42
    @test get_returnval(grandchild_ctx) == nothing

    set_returnval!(child_ctx, "test")
    @test get_returnval(root_ctx) == nothing
    @test get_returnval(child_ctx) == "test"
    @test get_returnval(grandchild_ctx) == nothing

    set_returnval!(root_ctx, 1)
    @test get_returnval(root_ctx) == 1
    @test get_returnval(child_ctx) == "test"
    @test get_returnval(grandchild_ctx) == nothing
end

@testitem "Variable Operations" begin
    import GraphPPL: ResizableArray, VariableNodeLabel, create_root_context, get_variable, set_variable!, has_variable

    ctx = create_root_context(Context)

    # Test scalar variable - method overloading equivalence
    var = VariableNodeLabel(1)

    # Test that set_variable! with and without nothing index are equivalent
    set_variable!(ctx, var, :x, nothing)
    set_variable!(ctx, var, :x_no_index)

    # Test that has_variable with and without nothing index are equivalent for scalars
    @test has_variable(ctx, :x, nothing)
    @test has_variable(ctx, :x)
    @test has_variable(ctx, :x_no_index, nothing)
    @test has_variable(ctx, :x_no_index)

    # Test that get_variable with and without nothing index are equivalent for scalars
    @test get_variable(ctx, :x, nothing) === var
    @test get_variable(ctx, :x) === var
    @test get_variable(ctx, :x_no_index, nothing) === var
    @test get_variable(ctx, :x_no_index) === var

    # Check that scalar variables are not accessible at an index (test all method overloads)
    @test !has_variable(ctx, :x, 1)
    @test !has_variable(ctx, :x, 1, 1)
    @test !has_variable(ctx, :x_no_index, 1)
    @test !has_variable(ctx, :x_no_index, 1, 1)
    @test_throws Exception get_variable(ctx, :x, 1)
    @test_throws Exception get_variable(ctx, :x, 1, 1)
    @test_throws Exception get_variable(ctx, :x_no_index, 1)
    @test_throws Exception get_variable(ctx, :x_no_index, 1, 1)

    # Test that setting individual elements on scalars should fail
    invalid_var = VariableNodeLabel(999)
    @test_throws Exception set_variable!(ctx, invalid_var, :x, 1)
    @test_throws Exception set_variable!(ctx, invalid_var, :x_no_index, 1)
    @test_throws Exception set_variable!(ctx, invalid_var, :x, (1, 2))

    # Check that non-existent variables are not accessible (test all method overloads)
    @test !has_variable(ctx, :y)
    @test !has_variable(ctx, :y, nothing)
    @test !has_variable(ctx, :y, 1)
    @test !has_variable(ctx, :y, 1, 1)
    @test_throws Exception get_variable(ctx, :y)
    @test_throws Exception get_variable(ctx, :y, nothing)
    @test_throws Exception get_variable(ctx, :y, 1)
    @test_throws Exception get_variable(ctx, :y, 1, 1)

    # Test vector variable - method overloading
    vec_var = ResizableArray(VariableNodeLabel)
    vec_var[1] = VariableNodeLabel(1)
    vec_var[2] = VariableNodeLabel(2)

    set_variable!(ctx, vec_var, :vec)

    # Test collection-level access (should work with and without nothing)
    @test has_variable(ctx, :vec)
    @test get_variable(ctx, :vec) === vec_var

    @test has_variable(ctx, :vec, nothing)
    @test get_variable(ctx, :vec, nothing) === vec_var

    # Test indexed access
    @test has_variable(ctx, :vec, 1)
    @test has_variable(ctx, :vec, 2)
    @test !has_variable(ctx, :vec, 3)
    @test !has_variable(ctx, :vec, 1, 1)
    @test get_variable(ctx, :vec, 1) === vec_var[1]
    @test get_variable(ctx, :vec, 2) === vec_var[2]
    @test_throws Exception get_variable(ctx, :vec, 3)

    # Test that vector variables don't work with multiple indices
    @test !has_variable(ctx, :vec, 1, 1)
    @test_throws Exception get_variable(ctx, :vec, 1, 1)

    # Test setting individual vector elements via set_variable!
    new_vec_var = VariableNodeLabel(99)
    set_variable!(ctx, vec_var, :vec2)  # Set the collection first
    set_variable!(ctx, new_vec_var, :vec2, 3)  # Set individual element
    @test has_variable(ctx, :vec2, 3)
    @test get_variable(ctx, :vec2, 3) === new_vec_var

    # Test setting elements in new vector positions
    another_var = VariableNodeLabel(88)
    set_variable!(ctx, another_var, :vec2, 5)
    @test has_variable(ctx, :vec2, 5)
    @test get_variable(ctx, :vec2, 5) === another_var

    # Test tensor variable - method overloading with varargs
    tensor_var = ResizableArray(VariableNodeLabel, Val(2))
    tensor_var[1, 1] = VariableNodeLabel(1)
    tensor_var[1, 2] = VariableNodeLabel(2)
    tensor_var[2, 1] = VariableNodeLabel(3)
    tensor_var[2, 2] = VariableNodeLabel(4)
    tensor_var[2, 3] = VariableNodeLabel(5)

    set_variable!(ctx, tensor_var, :tensor)

    # Test collection-level access
    @test has_variable(ctx, :tensor)
    @test get_variable(ctx, :tensor) === tensor_var
    @test has_variable(ctx, :tensor, nothing)
    @test get_variable(ctx, :tensor, nothing) === tensor_var

    # Test two-index access (indices...)
    @test has_variable(ctx, :tensor, 1, 1)
    @test has_variable(ctx, :tensor, 1, 2)
    @test has_variable(ctx, :tensor, 2, 1)
    @test has_variable(ctx, :tensor, 2, 2)
    @test has_variable(ctx, :tensor, 2, 3)
    @test get_variable(ctx, :tensor, 1, 1) === tensor_var[1, 1]
    @test get_variable(ctx, :tensor, 1, 2) === tensor_var[1, 2]
    @test get_variable(ctx, :tensor, 2, 3) === tensor_var[2, 3]

    # Test sparse tensor access (unassigned indices)
    @test !has_variable(ctx, :tensor, 1, 3)
    @test !has_variable(ctx, :tensor, 3, 1)
    @test_throws Exception get_variable(ctx, :tensor, 1, 3)
    @test_throws Exception get_variable(ctx, :tensor, 3, 1)

    # Test that tensor variables don't work with too many indices
    @test !has_variable(ctx, :tensor, 1, 1, 1)
    @test !has_variable(ctx, :tensor, 1, 1, 2)
    @test !has_variable(ctx, :tensor, 1, 2, 1)
    @test !has_variable(ctx, :tensor, 1, 2, 2)
    @test !has_variable(ctx, :tensor, 2, 1, 1)
    @test !has_variable(ctx, :tensor, 2, 1, 2)
    @test_throws Exception get_variable(ctx, :tensor, 1, 1, 1)
    @test_throws Exception get_variable(ctx, :tensor, 2, 1, 2)

    # Test setting individual tensor elements via set_variable!
    new_tensor_var = VariableNodeLabel(199)
    set_variable!(ctx, tensor_var, :tensor2)  # Set the collection first
    set_variable!(ctx, new_tensor_var, :tensor2, (3, 3))  # Set individual element with tuple
    @test has_variable(ctx, :tensor2, 3, 3)
    @test get_variable(ctx, :tensor2, 3, 3) === new_tensor_var

    # Test setting elements in new tensor positions
    another_tensor_var = VariableNodeLabel(188)
    set_variable!(ctx, another_tensor_var, :tensor2, (4, 2))
    @test has_variable(ctx, :tensor2, 4, 2)
    @test get_variable(ctx, :tensor2, 4, 2) === another_tensor_var

    # Test non-existent variables with all method overloads
    @test !has_variable(ctx, :nonexistent)
    @test !has_variable(ctx, :nonexistent, nothing)
    @test !has_variable(ctx, :nonexistent, 1)
    @test !has_variable(ctx, :nonexistent, 1, 2)
    @test_throws Exception get_variable(ctx, :nonexistent)
    @test_throws Exception get_variable(ctx, :nonexistent, nothing)
    @test_throws Exception get_variable(ctx, :nonexistent, 1)
    @test_throws Exception get_variable(ctx, :nonexistent, 1, 2)
end

@testitem "Factor Operations" begin
    import GraphPPL: FactorNodeLabel, create_root_context, get_factor, set_factor!, has_factor

    ctx = create_root_context(Context)

    @test !has_factor(ctx, sin)
    @test !has_factor(ctx, sin, 1)
    @test !has_factor(ctx, cos)
    @test !has_factor(ctx, cos, 1)

    # Create test factors
    factor1 = FactorNodeLabel(1)
    factor2 = FactorNodeLabel(2)
    factor3 = FactorNodeLabel(3)

    # Test setting and getting factors
    set_factor!(ctx, factor1, sin)
    set_factor!(ctx, factor2, cos)

    @test has_factor(ctx, sin)
    @test has_factor(ctx, sin, 1)
    @test has_factor(ctx, cos)
    @test has_factor(ctx, cos, 1)

    @test get_factor(ctx, sin) == [factor1]
    @test get_factor(ctx, cos) == [factor2]
    @test get_factor(ctx, sin, 1) === factor1
    @test get_factor(ctx, cos, 1) === factor2

    # Test non-existent factors
    @test_throws Exception get_factor(ctx, :nonexistent)

    # Test method overloading for factors
    set_factor!(ctx, factor3, sin)
    @test get_factor(ctx, sin) == [factor1, factor3]
    @test get_factor(ctx, sin, 1) === factor1
    @test get_factor(ctx, sin, 2) === factor3

    @test has_factor(ctx, sin, 2)
    @test !has_factor(ctx, cos, 2)

    @test get_factor(ctx, cos) == [factor2]
    @test get_factor(ctx, cos, 1) === factor2
    @test_throws BoundsError get_factor(ctx, cos, 2)
end

@testitem "Child Context Operations" begin
    import GraphPPL: VariableNodeLabel, create_root_context, create_child_context, get_children, has_children, proxylabel, has_variable

    root_ctx = create_root_context(Context)

    # Test initial state - method overloading
    @test !has_children(root_ctx, sin)
    @test !has_children(root_ctx, sin, 1)
    @test !has_children(root_ctx, cos)
    @test !has_children(root_ctx, cos, 1)
    @test !has_children(root_ctx, tan)
    @test !has_children(root_ctx, tan, 1)

    # Create interface variables
    interface_var1 = VariableNodeLabel(1)
    interface_var2 = VariableNodeLabel(2)
    interface_var3 = VariableNodeLabel(3)

    # Create and set child contexts with proper proxy labels
    proxy1 = proxylabel(:inputs, interface_var1, nothing)
    proxy2 = proxylabel(:inputs, interface_var2, nothing)
    proxy3 = proxylabel(:inputs, interface_var3, nothing)

    interfaces1 = (inputs = proxy1,)
    interfaces2 = (inputs = proxy2,)
    interfaces3 = (inputs = proxy3,)

    child1 = create_child_context(root_ctx, sin, interfaces1)
    child2 = create_child_context(root_ctx, cos, interfaces2)

    # Test has_children method overloads for single children
    @test has_children(root_ctx, sin)
    @test has_children(root_ctx, sin, 1)
    @test !has_children(root_ctx, sin, 2)
    @test has_children(root_ctx, cos)
    @test has_children(root_ctx, cos, 1)
    @test !has_children(root_ctx, cos, 2)

    # Test get_children method overloads for single children
    @test get_children(root_ctx, sin) == [child1]
    @test get_children(root_ctx, sin, 1) == child1
    @test get_children(root_ctx, cos) == [child2]
    @test get_children(root_ctx, cos, 1) == child2
    @test has_variable(child1, :inputs)
    @test has_variable(child2, :inputs)

    # Test multiple children of the same functional form
    child3 = create_child_context(root_ctx, sin, interfaces3)  # Second sin child

    # Test has_children method overloads for multiple children
    @test has_children(root_ctx, sin)      # Collection exists
    @test has_children(root_ctx, sin, 1)   # First child exists
    @test has_children(root_ctx, sin, 2)   # Second child exists
    @test !has_children(root_ctx, sin, 3)  # Third child doesn't exist

    # Test get_children method overloads for multiple children
    @test get_children(root_ctx, sin) == [child1, child3]  # Collection
    @test get_children(root_ctx, sin, 1) == child1         # First child
    @test get_children(root_ctx, sin, 2) == child3         # Second child

    # Test error conditions with method overloads
    @test_throws BoundsError get_children(root_ctx, sin, 3)  # Index out of bounds
    @test_throws BoundsError get_children(root_ctx, cos, 2)  # Index out of bounds for cos

    # Test nested child contexts
    grandchild = create_child_context(child1, tan, interfaces1)
    @test has_children(child1, tan)
    @test has_children(child1, tan, 1)
    @test !has_children(child1, tan, 2)
    @test get_children(child1, tan) == [grandchild]
    @test get_children(child1, tan, 1) == grandchild
    @test has_variable(grandchild, :inputs)

    # Test non-existent child contexts with all method overloads
    @test !has_children(root_ctx, exp)
    @test !has_children(root_ctx, exp, 1)
    @test !has_children(child1, sin)      # child1 has no sin children
    @test !has_children(child1, sin, 1)
    @test_throws Exception get_children(root_ctx, exp)
    @test_throws Exception get_children(root_ctx, exp, 1)
    @test_throws Exception get_children(child1, sin)
    @test_throws Exception get_children(child1, sin, 1)

    # Test that children are properly isolated by functional form
    child4 = create_child_context(root_ctx, cos, interfaces1)  # Second cos child

    # Verify sin children unchanged
    @test get_children(root_ctx, sin) == [child1, child3]
    @test get_children(root_ctx, sin, 1) == child1
    @test get_children(root_ctx, sin, 2) == child3

    # Verify cos children updated
    @test get_children(root_ctx, cos) == [child2, child4]
    @test get_children(root_ctx, cos, 1) == child2
    @test get_children(root_ctx, cos, 2) == child4
    @test has_children(root_ctx, cos, 2)
    @test !has_children(root_ctx, cos, 3)
end

@testitem "Markov Blanket Operations" begin
    import GraphPPL: VariableNodeLabel, create_root_context, create_child_context, has_variable, set_variable!, proxylabel

    # Create contexts
    parent_ctx = create_root_context(Context)

    # Setup interface variables in parent
    interface_var = VariableNodeLabel(1)
    set_variable!(parent_ctx, interface_var, :x)

    # Create child with markov blanket using proper proxy label
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(parent_ctx, sin, interfaces)

    # Test if interface variables are accessible in child
    @test !has_variable(child_ctx, :x)
    @test has_variable(child_ctx, :inputs)
    @test has_variable(child_ctx, :inputs, nothing)

    # Test nested markov blanket propagation
    grandchild_ctx = create_child_context(child_ctx, cos, interfaces)
    @test has_variable(grandchild_ctx, :inputs)
    @test !has_variable(grandchild_ctx, :x)
    @test !has_variable(grandchild_ctx, :x, nothing)
end

@testitem "Postprocess Return Value" begin
    import GraphPPL: Context, create_root_context, postprocess_returnval, set_returnval!, get_returnval

    ctx = create_root_context(Context)

    # Test that postprocess_returnval returns non-tuple values as-is
    @test postprocess_returnval(ctx, 42) === 42
    @test postprocess_returnval(ctx, "test") === "test"
    @test postprocess_returnval(ctx, [1, 2, 3]) == [1, 2, 3]
    @test postprocess_returnval(ctx, nothing) === nothing

    # Test postprocess_returnval with tuples - should process each element
    simple_tuple = (1, "hello", 3.14)
    processed_tuple = postprocess_returnval(ctx, simple_tuple)
    @test processed_tuple == (1, "hello", 3.14)
    @test processed_tuple isa Tuple

    # Test nested tuples - should recursively process
    nested_tuple = (1, (2, 3), "test")
    processed_nested = postprocess_returnval(ctx, nested_tuple)
    @test processed_nested == (1, (2, 3), "test")
    @test processed_nested isa Tuple

    # Test deeply nested tuples
    deep_tuple = (1, (2, (3, 4)), 5)
    processed_deep = postprocess_returnval(ctx, deep_tuple)
    @test processed_deep == (1, (2, (3, 4)), 5)

    # Test that set_returnval! uses postprocess_returnval
    # We can verify this by checking that tuple values are properly stored
    test_tuple = (42, "processed", [1, 2])
    set_returnval!(ctx, test_tuple)
    retrieved_value = get_returnval(ctx)
    @test retrieved_value == test_tuple
    @test retrieved_value isa Tuple

    # Test empty tuple
    empty_tuple = ()
    set_returnval!(ctx, empty_tuple)
    @test get_returnval(ctx) == ()
    @test get_returnval(ctx) isa Tuple

    # Test single element tuple
    single_tuple = (42,)
    processed_single = postprocess_returnval(ctx, single_tuple)
    @test processed_single == (42,)
    @test processed_single isa Tuple

    # Test mixed types in tuple
    mixed_tuple = (1, "string", [1, 2, 3], nothing, 3.14)
    processed_mixed = postprocess_returnval(ctx, mixed_tuple)
    @test processed_mixed == mixed_tuple
    @test processed_mixed isa Tuple

    # Test that the postprocessing is consistently applied through set_returnval!
    for test_value in [42, "test", [1, 2], (1, 2), (1, (2, 3)), nothing]
        set_returnval!(ctx, test_value)
        @test get_returnval(ctx) == test_value
        # Verify direct postprocessing gives same result
        @test postprocess_returnval(ctx, test_value) == get_returnval(ctx)
    end
end
