@testitem "Context Creation" setup = [MockLabels] begin
    import GraphPPL: ContextInterface, create_root_context, create_child_context, proxylabel

    # Test root context creation
    root_ctx = create_root_context(Context)
    @test root_ctx isa ContextInterface
    @test get_depth(root_ctx) == 0
    @test get_parent(root_ctx) === nothing

    # Test child context creation with proxy label
    interface_var = MockNodeLabel()
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(root_ctx, sin, interfaces)
    @test child_ctx isa ContextInterface
    @test get_depth(child_ctx) == 1
    @test get_parent(child_ctx) === root_ctx
    @test get_functional_form(child_ctx) == sin
end

@testitem "Basic Context Properties" setup = [MockLabels] begin
    import GraphPPL:
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
        proxylabel

    # Create test contexts
    root_ctx = create_root_context(Context)
    interface_var = MockNodeLabel()
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(root_ctx, sin, interfaces)
    grandchild_ctx = create_child_context(child_ctx, cos, interfaces)

    # Test depth hierarchy
    @test get_depth(root_ctx) == 0
    @test get_depth(child_ctx) == 1
    @test get_depth(grandchild_ctx) == 2

    # Test functional forms
    @test get_functional_form(child_ctx) == sin
    @test get_functional_form(grandchild_ctx) == cos

    # Test prefix and naming
    @test !isempty(get_prefix(root_ctx))
    @test !isempty(get_prefix(child_ctx))
    @test !isempty(get_short_name(root_ctx))
    @test !isempty(get_short_name(child_ctx))

    # Test parent relationships
    @test get_parent(root_ctx) === nothing
    @test get_parent(child_ctx) === root_ctx
    @test get_parent(grandchild_ctx) === child_ctx

    # Test return value setting and getting
    set_returnval!(child_ctx, 42)
    @test get_returnval(child_ctx) == 42
    set_returnval!(child_ctx, "test")
    @test get_returnval(child_ctx) == "test"

    # Test path to root
    root_path = get_path_to_root(grandchild_ctx)
    @test length(root_path) == 3
    @test root_path[1] === grandchild_ctx
    @test root_path[2] === child_ctx
    @test root_path[3] === root_ctx
end

@testitem "Variable Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, get_variable, set_variable!, has_variable

    ctx = create_root_context(Context)

    # Test scalar variable
    var = MockNodeLabel()
    set_variable!(ctx, var, nothing)
    @test has_variable(ctx, :x, nothing)
    @test get_variable(ctx, :x, nothing) === var

    # Test vector variable
    vec_var = [MockNodeLabel() for _ in 1:3]
    set_variable!(ctx, vec_var, :vec)
    @test has_variable(ctx, :vec, 1)
    @test get_variable(ctx, :vec, 1) === vec_var[1]
    @test get_variable(ctx, :vec, 2) === vec_var[2]

    # Test tensor variable
    tensor_var = reshape([MockNodeLabel() for _ in 1:6], 2, 3)
    set_variable!(ctx, tensor_var, ())
    @test has_variable(ctx, :tensor, (1, 1))
    @test get_variable(ctx, :tensor, (1, 1)) === tensor_var[1, 1]
    @test get_variable(ctx, :tensor, (2, 3)) === tensor_var[2, 3]

    # Test non-existent variables
    @test !has_variable(ctx, :nonexistent, nothing)
    @test_throws Exception get_variable(ctx, :nonexistent, nothing)
end

@testitem "Factor Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, get_factor, set_factor_node!

    ctx = create_root_context(Context)

    # Create test factors
    factor1 = MockFactorNodeLabel()
    factor2 = MockFactorNodeLabel()

    # Test setting and getting factors
    set_factor_node!(ctx, sin, :factor1, factor1)
    set_factor_node!(ctx, cos, :factor2, factor2)

    @test get_factor(ctx, :factor1) === factor1
    @test get_factor(ctx, :factor2) === factor2

    # Test non-existent factors
    @test_throws Exception get_factor(ctx, :nonexistent)
end

@testitem "Child Context Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, create_child_context, get_child_context, set_child_context!, proxylabel

    root_ctx = create_root_context(Context)

    # Create interface variables
    interface_var1 = MockNodeLabel()
    interface_var2 = MockNodeLabel()

    # Create and set child contexts with proper proxy labels
    proxy1 = proxylabel(:inputs, interface_var1, nothing)
    proxy2 = proxylabel(:inputs, interface_var2, nothing)

    interfaces1 = (inputs = proxy1,)
    interfaces2 = (inputs = proxy2,)

    child1 = create_child_context(root_ctx, sin, interfaces1)
    child2 = create_child_context(root_ctx, cos, interfaces2)

    set_child_context!(root_ctx, sin, :child1, child1)
    set_child_context!(root_ctx, cos, :child2, child2)

    # Test retrieving child contexts
    @test get_child_context(root_ctx, sin, :child1) === child1
    @test get_child_context(root_ctx, cos, :child2) === child2

    # Test nested child contexts
    proxy3 = proxylabel(:inputs, interface_var1, nothing)
    interfaces3 = (inputs = proxy3,)
    grandchild = create_child_context(child1, tan, interfaces3)
    set_child_context!(child1, tan, :grandchild, grandchild)
    @test get_child_context(child1, tan, :grandchild) === grandchild

    # Test non-existent child contexts
    @test_throws Exception get_child_context(root_ctx, tan, :nonexistent)
end

@testitem "Markov Blanket Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, create_child_context, get_variable, set_variable!, proxylabel

    # Create contexts
    parent_ctx = create_root_context(Context)

    # Setup interface variables in parent
    interface_var = MockNodeLabel()
    set_variable!(parent_ctx, interface_var, nothing)

    # Create child with markov blanket using proper proxy label
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(parent_ctx, sin, interfaces)

    # Test if interface variables are accessible in child
    @test get_variable(child_ctx, :inputs, nothing) === interface_var

    # Test nested markov blanket propagation
    grandchild_ctx = create_child_context(child_ctx, cos, interfaces)
    @test get_variable(grandchild_ctx, :inputs, nothing) === interface_var
end
