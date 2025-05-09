# Basic functionality tests
@testitem "VariableNodeData construction and basic properties" begin
    import GraphPPL:
        VariableNodeData,
        get_name,
        get_kind,
        get_value,
        get_index,
        get_link,
        get_context,
        is_random,
        is_data,
        is_constant,
        is_anonymous,
        has_extra,
        get_extra,
        set_extra!
    # Test basic constructor
    vnd = VariableNodeData(name = :test, kind = :random, value = 5)
    @test get_name(vnd) === :test
    @test get_kind(vnd) === :random
    @test get_value(vnd) === 5

    # Test with all fields
    vnd = VariableNodeData(name = :full_test, index = 2, link = "some_link", kind = :data, value = 10.5, context = "test_context")
    @test get_name(vnd) === :full_test
    @test get_index(vnd) === 2
    @test get_link(vnd) === "some_link"
    @test get_kind(vnd) === :data
    @test get_value(vnd) === 10.5
    @test get_context(vnd) === "test_context"
end

# Variable kind tests
@testitem "VariableNodeData kind tests" begin
    import GraphPPL: VariableNodeData, is_random, is_data, is_constant
    # Test random variable
    random_var = VariableNodeData(name = :x, kind = :random)
    @test is_random(random_var) === true
    @test is_data(random_var) === false
    @test is_constant(random_var) === false

    # Test data variable
    data_var = VariableNodeData(name = :y, kind = :data)
    @test is_random(data_var) === false
    @test is_data(data_var) === true
    @test is_constant(data_var) === false

    # Test constant variable
    const_var = VariableNodeData(name = :z, kind = :constant)
    @test is_random(const_var) === false
    @test is_data(const_var) === false
    @test is_constant(const_var) === true

    # Test unknown kind
    custom_var = VariableNodeData(name = :custom, kind = :custom)
    @test is_random(custom_var) === false
    @test is_data(custom_var) === false
    @test is_constant(custom_var) === false
end

# Anonymous variable test
@testitem "VariableNodeData anonymous test" begin
    import GraphPPL: VariableNodeData, is_anonymous
    # Test anonymous variable
    anon_var = VariableNodeData(name = :anonymous_var_graphppl)
    @test is_anonymous(anon_var) === true

    # Test named variable
    named_var = VariableNodeData(name = :x)
    @test is_anonymous(named_var) === false
end

# Extra properties tests
@testitem "VariableNodeData extra properties" begin
    import GraphPPL: VariableNodeData, has_extra, get_extra, set_extra!
    vnd = VariableNodeData(name = :test)

    # Test initial state
    @test !has_extra(vnd, :extra_key)
    @test_throws KeyError get_extra(vnd, :extra_key)
    @test get_extra(vnd, :extra_key, "default") === "default"
    @test get_extra(vnd) isa Dict{Symbol, Any}
    @test isempty(get_extra(vnd))

    # Test setting and getting extras
    set_extra!(vnd, :extra_key, "extra_value")
    @test has_extra(vnd, :extra_key)
    @test get_extra(vnd, :extra_key) === "extra_value"
    @test get_extra(vnd, :extra_key, "default") === "extra_value"
    @test !isempty(get_extra(vnd))
    @test haskey(get_extra(vnd), :extra_key)

    # Test overwriting
    set_extra!(vnd, :extra_key, 42)
    @test get_extra(vnd, :extra_key) === 42

    # Test multiple extras
    set_extra!(vnd, :another_key, "another_value")
    @test has_extra(vnd, :another_key)
    @test get_extra(vnd, :another_key) === "another_value"
    @test length(get_extra(vnd)) == 2
end

# Complete interface implementation test
@testitem "VariableNodeData implements all VariableNodeDataInterface methods" begin
    import GraphPPL:
        VariableNodeData,
        get_name,
        get_index,
        get_link,
        get_kind,
        get_value,
        is_random,
        is_data,
        is_constant,
        is_anonymous,
        get_context,
        has_extra,
        get_extra,
        set_extra!
    vnd = VariableNodeData(name = :test)

    # Test that all interface methods work without throwing
    # GraphPPLInterfaceNotImplemented exceptions
    @test_nowarn get_name(vnd)
    @test_nowarn get_index(vnd)
    @test_nowarn get_link(vnd)
    @test_nowarn get_kind(vnd)
    @test_nowarn get_value(vnd)
    @test_nowarn is_random(vnd)
    @test_nowarn is_data(vnd)
    @test_nowarn is_constant(vnd)
    @test_nowarn is_anonymous(vnd)
    @test_nowarn get_context(vnd)
    @test_nowarn has_extra(vnd, :test)
    @test_nowarn get_extra(vnd)
    @test_nowarn get_extra(vnd, :test, nothing)
    @test_nowarn set_extra!(vnd, :test, "value")
    @test_nowarn get_extra(vnd, :test)
end

@testitem "test that VariableNodeData methods do not allocate" begin
    import GraphPPL:
        VariableNodeData,
        get_name,
        get_index,
        get_link,
        get_kind,
        get_value,
        is_random,
        is_data,
        is_constant,
        is_anonymous,
        has_extra,
        get_extra,
        set_extra!
    vnd = VariableNodeData(name = :test)
    @test @allocated(get_name(vnd)) == 0
    @test @allocated(get_index(vnd)) == 0
    @test @allocated(get_link(vnd)) == 0
    @test @allocated(get_kind(vnd)) == 0
    @test @allocated(get_value(vnd)) == 0
    @test @allocated(is_random(vnd)) == 0
    @test @allocated(is_data(vnd)) == 0
    @test @allocated(is_constant(vnd)) == 0
    @test @allocated(is_anonymous(vnd)) == 0
    @test @allocated(has_extra(vnd, :test)) == 0
    @test @allocated(get_extra(vnd, :test, "default")) == 0
    @test @allocated(get_extra(vnd)) == 0
    @test @allocated(set_extra!(vnd, :test, "value")) == 0
    @test @allocated(get_extra(vnd, :test)) == 0
end
