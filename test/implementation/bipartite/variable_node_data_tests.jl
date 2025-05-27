
@testitem "VariableNodeData creation with `create_variable_data`" begin
    import GraphPPL: VariableNodeData, get_name, get_kind, get_value, get_index, get_link, create_variable_data, VariableNodeKind

    # Test basic creation
    vnd = create_variable_data(VariableNodeData, name = :test, kind = VariableNodeKind.Random, value = 5)
    @test @inferred(get_name(vnd)) === :test
    @test @inferred(get_kind(vnd)) === VariableNodeKind.Random
    @test get_value(vnd) === 5

    # Test with all fields
    vnd = create_variable_data(
        VariableNodeData, name = :full_test, index = 2, link = "some_link", kind = VariableNodeKind.Data, value = 10.5
    )
    @test get_name(vnd) === :full_test
    @test get_index(vnd) === 2
    @test get_link(vnd) === "some_link"
    @test get_kind(vnd) === VariableNodeKind.Data
    @test get_value(vnd) === 10.5
end

@testitem "VariableNodeData kind tests" begin
    import GraphPPL: VariableNodeData, is_random, is_data, is_constant, create_variable_data, VariableNodeKind

    # Test random variable
    random_var = create_variable_data(VariableNodeData, name = :x, kind = VariableNodeKind.Random)
    @test @inferred(is_random(random_var)) === true
    @test @inferred(is_data(random_var)) === false
    @test @inferred(is_constant(random_var)) === false

    # Test data variable
    data_var = create_variable_data(VariableNodeData, name = :y, kind = VariableNodeKind.Data)
    @test @inferred(is_random(data_var)) === false
    @test @inferred(is_data(data_var)) === true
    @test @inferred(is_constant(data_var)) === false

    # Test constant variable
    const_var = create_variable_data(VariableNodeData, name = :z, kind = VariableNodeKind.Constant)
    @test @inferred(is_random(const_var)) === false
    @test @inferred(is_data(const_var)) === false
    @test @inferred(is_constant(const_var)) === true

    # Test unspecified kind
    unspec_var = create_variable_data(VariableNodeData, name = :unspec)
    @test @inferred(is_random(unspec_var)) === false
    @test @inferred(is_data(unspec_var)) === false
    @test @inferred(is_constant(unspec_var)) === false
end

@testitem "VariableNodeData anonymous test" begin
    import GraphPPL: VariableNodeData, VariableNodeKind, is_anonymous, create_variable_data

    # Test anonymous variable
    anon_var = create_variable_data(VariableNodeData, name = :x, kind = VariableNodeKind.Anonymous)
    @test is_anonymous(anon_var) === true

    # Test named variable
    named_var = create_variable_data(VariableNodeData, name = :x)
    @test is_anonymous(named_var) === false
end

@testitem "VariableNodeData implements has_extra with Symbol keys" begin
    import GraphPPL: VariableNodeData, has_extra, get_extra, set_extra!, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test)

    # Initially, no extras should exist
    @test !has_extra(vnd, :test_key)

    # After setting an extra, it should exist
    set_extra!(vnd, :test_key, "test_value")
    @test has_extra(vnd, :test_key)
    @test get_extra(vnd, :test_key) == "test_value"

    # Non-existent keys should return false
    @test !has_extra(vnd, :nonexistent_key)
end

@testitem "VariableNodeData implements has_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: VariableNodeData, has_extra, set_extra!, CompileTimeDictionaryKey, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test)
    key = CompileTimeDictionaryKey{:test_key, String}()

    # Initially, no extras should exist
    @test !has_extra(vnd, key)

    # After setting an extra, it should exist
    set_extra!(vnd, key, "test_value")
    @test has_extra(vnd, key)

    # Different key should not exist
    other_key = CompileTimeDictionaryKey{:other_key, Int}()
    @test !has_extra(vnd, other_key)
end

@testitem "VariableNodeData implements get_extra with Symbol keys" begin
    import GraphPPL: VariableNodeData, get_extra, set_extra!, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test)

    # Set and get an extra
    set_extra!(vnd, :test_key, "test_value")
    @test get_extra(vnd, :test_key) == "test_value"

    # Get with default for existing key
    @test get_extra(vnd, :test_key, "default") == "test_value"

    # Get with default for non-existent key
    @test get_extra(vnd, :nonexistent_key, "default") == "default"

    # Getting non-existent key without default should throw
    @test_throws KeyError get_extra(vnd, :nonexistent_key)
end

@testitem "VariableNodeData implements get_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: VariableNodeData, get_extra, set_extra!, CompileTimeDictionaryKey, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test)
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set and get extras with type safety
    set_extra!(vnd, string_key, "test_value")
    set_extra!(vnd, int_key, 42)

    @test @inferred(get_extra(vnd, string_key)) == "test_value"
    @test @inferred(get_extra(vnd, int_key)) == 42

    # Get with default for existing key
    @test @inferred(get_extra(vnd, string_key, "default")) == "test_value"
    @test @inferred(get_extra(vnd, int_key, 0)) == 42

    # Get with default for non-existent key
    float_key = CompileTimeDictionaryKey{:float_key, Float64}()
    @test get_extra(vnd, float_key, 3.14) == 3.14

    # Type safety check - should return the correct type
    @test get_extra(vnd, int_key) isa Int
    @test get_extra(vnd, string_key) isa String
end

@testitem "VariableNodeData implements set_extra! with Symbol keys" begin
    import GraphPPL: VariableNodeData, get_extra, set_extra!, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test)

    # Set a new extra
    @test set_extra!(vnd, :test_key, "test_value") == "test_value"
    @test get_extra(vnd, :test_key) == "test_value"

    # Overwrite an existing extra
    @test set_extra!(vnd, :test_key, "new_value") == "new_value"
    @test get_extra(vnd, :test_key) == "new_value"

    # Set extras of different types
    @test set_extra!(vnd, :int_key, 42) == 42
    @test set_extra!(vnd, :bool_key, true) == true

    @test get_extra(vnd, :int_key) == 42
    @test get_extra(vnd, :bool_key) == true
end

@testitem "VariableNodeData implements set_extra! with CompileTimeDictionaryKey" begin
    import GraphPPL: VariableNodeData, get_extra, set_extra!, CompileTimeDictionaryKey, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test)
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set new extras with type safety
    @test set_extra!(vnd, string_key, "test_value") == "test_value"
    @test set_extra!(vnd, int_key, 42) == 42

    @test get_extra(vnd, string_key) == "test_value"
    @test get_extra(vnd, int_key) == 42

    # Overwrite existing extras
    @test set_extra!(vnd, string_key, "new_value") == "new_value"
    @test get_extra(vnd, string_key) == "new_value"
end

@testitem "VariableNodeData show method" begin
    import GraphPPL: VariableNodeData, VariableNodeKind, set_extra!, create_variable_data

    vnd = create_variable_data(VariableNodeData, name = :test, kind = VariableNodeKind.Random)
    set_extra!(vnd, :test_key, "test_value")

    # Test string representation
    str = sprint(show, vnd)
    @test occursin("VariableNodeData", str)
    @test occursin(":test", str)
    @test occursin("test_key", str)
    @test occursin("test_value", str)
end

@testitem "VariableNodeData satisfies VariableNodeDataInterface" begin
    import GraphPPL:
        VariableNodeData,
        VariableNodeDataInterface,
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
        set_extra!,
        CompileTimeDictionaryKey,
        create_variable_data,
        VariableNodeKind

    # Verify VariableNodeData is a subtype of VariableNodeDataInterface
    @test VariableNodeData <: VariableNodeDataInterface

    # Create a test instance
    vnd = create_variable_data(VariableNodeData, name = :test, kind = VariableNodeKind.Random)

    # Test all interface methods are implemented
    @test get_name(vnd) === :test
    @test get_kind(vnd) === VariableNodeKind.Random
    @test get_index(vnd) === nothing
    @test get_link(vnd) === nothing
    @test get_value(vnd) === nothing

    # Test kind predicates
    @test is_random(vnd) === true
    @test is_data(vnd) === false
    @test is_constant(vnd) === false
    @test is_anonymous(vnd) === false

    # Test extras management
    @test !has_extra(vnd, :test_key)
    set_extra!(vnd, :test_key, "test_value")
    @test has_extra(vnd, :test_key)
    @test get_extra(vnd, :test_key) == "test_value"
    @test get_extra(vnd, :nonexistent, "default") == "default"

    # Test CompileTimeDictionaryKey interface
    key = CompileTimeDictionaryKey{:typed_key, Int}()
    @test !has_extra(vnd, key)
    set_extra!(vnd, key, 42)
    @test has_extra(vnd, key)
    @test get_extra(vnd, key) == 42
    @test get_extra(vnd, CompileTimeDictionaryKey{:nonexistent, Float64}(), 3.14) == 3.14
end

@testitem "test that VariableNodeData methods do not allocate" begin
    import GraphPPL:
        VariableNodeData,
        create_variable_data,
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
    vnd = create_variable_data(VariableNodeData, name = :test)
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
    set_extra!(vnd, :test, "value")
    @test @allocated(get_extra(vnd, :test)) == 0
end

@testitem "create_variable_data interface test" begin
    import GraphPPL:
        VariableNodeData,
        VariableNodeKind,
        create_variable_data,
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

    # Test that create_variable_data works with all arguments
    vnd = create_variable_data(
        VariableNodeData, name = :test_var, index = 1, kind = VariableNodeKind.Random, link = "test_link", value = 42.0
    )

    @test get_name(vnd) === :test_var
    @test get_index(vnd) === 1
    @test get_kind(vnd) === VariableNodeKind.Random
    @test get_link(vnd) === "test_link"
    @test get_value(vnd) === 42.0

    # Test with minimal arguments
    vnd_minimal = create_variable_data(VariableNodeData, name = :minimal_var, kind = VariableNodeKind.Data)

    @test get_name(vnd_minimal) === :minimal_var
    @test get_index(vnd_minimal) === nothing
    @test get_kind(vnd_minimal) === VariableNodeKind.Data
    @test get_link(vnd_minimal) === nothing
    @test get_value(vnd_minimal) === nothing
end

@testitem "is_constant" setup = [TestUtils] begin
    import GraphPPL: create_model, is_constant, variable_nodes, getname, getproperties

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
        for label in variable_nodes(model)
            node = model[label]
            props = getproperties(node)
            if occursin("constvar", string(getname(props)))
                @test is_constant(props)
            else
                @test !is_constant(props)
            end
        end
    end
end

@testitem "is_data" setup = [TestUtils] begin
    import GraphPPL: is_data, create_model, getcontext, getorcreate!, variable_nodes, NodeCreationOptions, getproperties

    m = TestUtils.create_test_model()
    ctx = getcontext(m)
    xref = getorcreate!(m, ctx, NodeCreationOptions(kind = :data), :x, nothing)
    @test is_data(getproperties(m[xref]))

    # Since the models here are without top arguments they cannot create `data` labels
    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
        for label in variable_nodes(model)
            @test !is_data(getproperties(model[label]))
        end
    end
end

@testitem "Predefined kinds of variable nodes" setup = [TestUtils] begin
    import GraphPPL: VariableKindRandom, VariableKindData, VariableKindConstant
    import GraphPPL: getcontext, getorcreate!, NodeCreationOptions, getproperties

    model = TestUtils.create_test_model()
    context = getcontext(model)
    xref = getorcreate!(model, context, NodeCreationOptions(kind = VariableKindRandom), :x, nothing)
    y = getorcreate!(model, context, NodeCreationOptions(kind = VariableKindData), :y, nothing)
    zref = getorcreate!(model, context, NodeCreationOptions(kind = VariableKindConstant), :z, nothing)

    import GraphPPL: is_random, is_data, is_constant, is_kind

    xprops = getproperties(model[xref])
    yprops = getproperties(model[y])
    zprops = getproperties(model[zref])

    @test is_random(xprops) && is_kind(xprops, VariableKindRandom)
    @test is_data(yprops) && is_kind(yprops, VariableKindData)
    @test is_constant(zprops) && is_kind(zprops, VariableKindConstant)
end