@testitem "Basic Context Properties" setup = [MockLabels] begin
    import GraphPPL:
        Context, create_context, create_child_context, get_depth, get_functional_form, get_parent, get_returnval, get_path_to_root
    # Test setup - create parent and child contexts properly
    parent_ctx = create_context(Context, MockFactorIdentifier, MockFactorNodeLabel, MockVariableNodeLabel)
    child_ctx = create_child_context(parent_ctx, sin)

    # Set some test properties on child context
    set_returnval!(child_ctx, 42)

    # Test basic property getters
    @test get_depth(child_ctx) == 1  # Child should be one level deeper than parent
    @test get_functional_form(child_ctx) == sin
    @test get_parent(child_ctx) === parent_ctx
    @test get_returnval(child_ctx) == 42

    # Test return value setter
    set_returnval!(child_ctx, 43)
    @test get_returnval(child_ctx) == 43

    # Test path to root
    @test get_path_to_root(child_ctx) == [child_ctx, parent_ctx]
end

@testitem "Individual Variable Operations" begin
    ctx = Context()
    var = MockNodeLabel()

    # Test setting and getting individual variables
    set_individual_variable!(ctx, :x, var)
    @test has_individual_variable(ctx, :x)
    @test get_individual_variable(ctx, :x) === var
    @test !has_individual_variable(ctx, :nonexistent)
    @test_throws KeyError get_individual_variable(ctx, :nonexistent)

    # Test generic variable interface for individual variables
    @test has_variable(ctx, :x)
    @test get_variable(ctx, :x) === var
    set_variable!(ctx, :y, var)
    @test has_variable(ctx, :y)
    @test get_variable(ctx, :y) === var
end

@testitem "Vector Variable Operations" begin
    ctx = Context()
    vars = [MockNodeLabel() for _ in 1:3]

    # Test setting and getting vector variables
    set_vector_variable_array!(ctx, :x, vars)
    @test has_vector_variable(ctx, :x)
    @test get_vector_variable(ctx, :x, 1) === vars[1]
    @test get_vector_variable(ctx, :x, 2) === vars[2]

    # Test individual element setting
    new_var = MockNodeLabel()
    set_vector_variable!(ctx, :x, 2, new_var)
    @test get_vector_variable(ctx, :x, 2) === new_var

    # Test generic variable interface for vector variables
    @test has_variable(ctx, :x)
    @test get_variable(ctx, :x, 1) === vars[1]
    set_variable!(ctx, :y, vars)
    @test has_variable(ctx, :y)
    @test get_variable(ctx, :y, 1) === vars[1]
end

@testitem "Tensor Variable Operations" begin
    ctx = Context()
    vars = reshape([MockNodeLabel() for _ in 1:6], (2, 3))

    # Test setting and getting tensor variables
    set_tensor_variable_array!(ctx, :x, vars)
    @test has_tensor_variable(ctx, :x)
    @test get_tensor_variable(ctx, :x, (1, 1)) === vars[1, 1]
    @test get_tensor_variable(ctx, :x, (2, 3)) === vars[2, 3]

    # Test individual element setting
    new_var = MockNodeLabel()
    set_tensor_variable!(ctx, :x, (1, 2), new_var)
    @test get_tensor_variable(ctx, :x, (1, 2)) === new_var

    # Test generic variable interface for tensor variables
    @test has_variable(ctx, :x)
    @test get_variable(ctx, :x, (1, 1)) === vars[1, 1]
    set_variable!(ctx, :y, vars)
    @test has_variable(ctx, :y)
    @test get_variable(ctx, :y, (1, 1)) === vars[1, 1]
end

@testitem "Proxy Operations" begin
    ctx = Context()
    proxy = MockProxyLabel()

    # Test setting and getting proxies
    set_proxy!(ctx, :p, proxy)
    @test has_proxy(ctx, :p)
    @test get_proxy(ctx, :p) === proxy
    @test !has_proxy(ctx, :nonexistent)
    @test_throws KeyError get_proxy(ctx, :nonexistent)

    # Test generic variable interface for proxies
    @test has_variable(ctx, :p)
    @test get_variable(ctx, :p) === proxy
    set_variable!(ctx, :q, proxy)
    @test has_variable(ctx, :q)
    @test get_variable(ctx, :q) === proxy
end

@testitem "Child Context Management" begin
    # Create root context
    root_ctx = Context()

    # Create child contexts with different functional forms
    child1 = create_child_context(root_ctx, sin)
    child2 = create_child_context(root_ctx, cos)

    # Test setting child contexts
    set_child_context!(root_ctx, sin, :test1, child1)
    set_child_context!(root_ctx, cos, :test2, child2)

    # Test retrieving child contexts
    @test has_child_context(root_ctx, sin, :test1)
    @test has_child_context(root_ctx, cos, :test2)
    @test get_child_context(root_ctx, sin, :test1) === child1
    @test get_child_context(root_ctx, cos, :test2) === child2

    # Test non-existent child contexts
    @test !has_child_context(root_ctx, tan, :nonexistent)
    @test_throws KeyError get_child_context(root_ctx, tan, :nonexistent)

    # Test generic node interface for child contexts
    @test get_node(root_ctx, sin, :test1) === child1
    @test get_node(root_ctx, cos, :test2) === child2

    # Test child context properties
    @test get_parent(child1) === root_ctx
    @test get_parent(child2) === root_ctx
    @test get_functional_form(child1) == sin
    @test get_functional_form(child2) == cos
    @test get_depth(child1) == get_depth(root_ctx) + 1
    @test get_depth(child2) == get_depth(root_ctx) + 1
end

@testitem "Collection Operations" begin
    ctx = Context()

    # Add some test data
    var1, var2 = MockNodeLabel(), MockNodeLabel()
    vec_vars = [MockNodeLabel(), MockNodeLabel()]
    tensor_vars = reshape([MockNodeLabel() for _ in 1:4], (2, 2))
    proxy = MockProxyLabel()

    # Create and set up child contexts
    child1 = create_child_context(ctx, sin)
    child2 = create_child_context(ctx, cos)

    # Set various elements
    set_individual_variable!(ctx, :x, var1)
    set_individual_variable!(ctx, :y, var2)
    set_vector_variable_array!(ctx, :vec, vec_vars)
    set_tensor_variable_array!(ctx, :tensor, tensor_vars)
    set_proxy!(ctx, :proxy, proxy)
    set_child_context!(ctx, sin, :child1, child1)
    set_child_context!(ctx, cos, :child2, child2)

    # Test collection getters
    @test length(get_individual_variables(ctx)) == 2
    @test length(get_vector_variables(ctx)) == 1
    @test length(get_tensor_variables(ctx)) == 1
    @test length(get_proxies(ctx)) == 1
    @test length(get_children(ctx)) == 2
end

@testitem "Markov Blanket Operations" begin
    # Create parent and child contexts
    parent_ctx = Context()
    child_ctx = create_child_context(parent_ctx, sin)

    # Setup some interface variables in parent
    interface_var = MockNodeLabel()
    set_individual_variable!(parent_ctx, :interface, interface_var)

    # Define interfaces to copy
    interfaces = (inputs = [:interface],)

    # Test copying interfaces
    copy_markov_blanket_to_child!(child_ctx, interfaces)
    @test has_individual_variable(child_ctx, :interface)
    @test get_individual_variable(child_ctx, :interface) === interface_var
end
