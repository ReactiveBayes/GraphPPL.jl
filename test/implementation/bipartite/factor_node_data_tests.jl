@testitem "FactorNodeData creation with `create_factor_data`" begin
    import GraphPPL: FactorNodeData, get_functional_form, create_factor_data

    for functional_form in ["test_form", "test_form_2", identity, (x) -> x]
        factor_data = create_factor_data(FactorNodeData, functional_form = functional_form)
        @test get_functional_form(factor_data) == functional_form
        @test occursin(repr(functional_form), repr(factor_data))
    end
end

@testitem "FactorNodeData implements get_functional_form" begin
    import GraphPPL: FactorNodeData, get_functional_form, create_factor_data

    form = "test_form"
    factor_data = create_factor_data(FactorNodeData, functional_form = form)

    @test get_functional_form(factor_data) === form
end

@testitem "FactorNodeData implements has_extra with Symbol keys" begin
    import GraphPPL: FactorNodeData, create_factor_data, has_extra, set_extra!, get_extra

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")

    # Initially, no extras should exist
    @test !has_extra(factor_data, :test_key)

    # After setting an extra, it should exist
    set_extra!(factor_data, :test_key, "test_value")
    @test has_extra(factor_data, :test_key)
    @test get_extra(factor_data, :test_key) == "test_value"

    # Non-existent keys should return false
    @test !has_extra(factor_data, :nonexistent_key)
end

@testitem "FactorNodeData implements has_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: FactorNodeData, has_extra, set_extra!, CompileTimeDictionaryKey, create_factor_data

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")
    key = CompileTimeDictionaryKey{:test_key, String}()

    # Initially, no extras should exist
    @test !has_extra(factor_data, key)

    # After setting an extra, it should exist
    set_extra!(factor_data, key, "test_value")
    @test has_extra(factor_data, key)

    # Different key should not exist
    other_key = CompileTimeDictionaryKey{:other_key, Int}()
    @test !has_extra(factor_data, other_key)
end

@testitem "FactorNodeData implements get_extra with Symbol keys" begin
    import GraphPPL: FactorNodeData, get_extra, set_extra!, create_factor_data

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")

    # Set and get an extra
    set_extra!(factor_data, :test_key, "test_value")
    @test get_extra(factor_data, :test_key) == "test_value"

    # Get with default for existing key
    @test get_extra(factor_data, :test_key, "default") == "test_value"

    # Get with default for non-existent key
    @test get_extra(factor_data, :nonexistent_key, "default") == "default"

    # Getting non-existent key without default should throw
    @test_throws KeyError get_extra(factor_data, :nonexistent_key)
end

@testitem "FactorNodeData implements get_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: FactorNodeData, get_extra, set_extra!, CompileTimeDictionaryKey, create_factor_data

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set and get extras with type safety
    set_extra!(factor_data, string_key, "test_value")
    set_extra!(factor_data, int_key, 42)

    @test @inferred(get_extra(factor_data, string_key)) == "test_value"
    @test @inferred(get_extra(factor_data, int_key)) == 42

    # Get with default for existing key
    @test @inferred(get_extra(factor_data, string_key, "default")) == "test_value"
    @test @inferred(get_extra(factor_data, int_key, 0)) == 42

    # Get with default for non-existent key
    float_key = CompileTimeDictionaryKey{:float_key, Float64}()
    @test get_extra(factor_data, float_key, 3.14) == 3.14

    # Type safety check - should return the correct type
    @test get_extra(factor_data, int_key) isa Int
    @test get_extra(factor_data, string_key) isa String
end

@testitem "FactorNodeData implements set_extra! with Symbol keys" begin
    import GraphPPL: FactorNodeData, get_extra, set_extra!, create_factor_data

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")

    # Set a new extra
    @test set_extra!(factor_data, :test_key, "test_value") == "test_value"
    @test get_extra(factor_data, :test_key) == "test_value"

    # Overwrite an existing extra
    @test set_extra!(factor_data, :test_key, "new_value") == "new_value"
    @test get_extra(factor_data, :test_key) == "new_value"

    # Set extras of different types
    @test set_extra!(factor_data, :int_key, 42) == 42
    @test set_extra!(factor_data, :bool_key, true) == true

    @test get_extra(factor_data, :int_key) == 42
    @test get_extra(factor_data, :bool_key) == true
end

@testitem "FactorNodeData implements set_extra! with CompileTimeDictionaryKey" begin
    import GraphPPL: FactorNodeData, get_extra, set_extra!, CompileTimeDictionaryKey, create_factor_data

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set new extras with type safety
    @test @inferred(set_extra!(factor_data, string_key, "test_value")) == "test_value"
    @test @inferred(set_extra!(factor_data, int_key, 42)) == 42

    @test get_extra(factor_data, string_key) == "test_value"
    @test get_extra(factor_data, int_key) == 42

    # Overwrite existing extras
    @test set_extra!(factor_data, string_key, "new_value") == "new_value"
    @test get_extra(factor_data, string_key) == "new_value"
end

@testitem "FactorNodeData show method" begin
    import GraphPPL: FactorNodeData, set_extra!, create_factor_data

    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")
    set_extra!(factor_data, :test_key, "test_value")

    # Test string representation
    str = sprint(show, factor_data)
    @test occursin("FactorNodeData", str)
    @test occursin("test_form", str)
    @test occursin("test_key", str)
    @test occursin("test_value", str)
end

@testitem "FactorNodeData satisfies FactorNodeDataInterface" begin
    import GraphPPL:
        FactorNodeData,
        FactorNodeDataInterface,
        get_functional_form,
        has_extra,
        get_extra,
        set_extra!,
        CompileTimeDictionaryKey,
        create_factor_data

    # Verify FactorNodeData is a subtype of FactorNodeDataInterface
    @test FactorNodeData <: FactorNodeDataInterface

    # Create a test instance
    factor_data = create_factor_data(FactorNodeData, functional_form = "test_form")

    # Test all interface methods are implemented
    @test get_functional_form(factor_data) == "test_form"

    # Test extras management
    @test !has_extra(factor_data, :test_key)
    set_extra!(factor_data, :test_key, "test_value")
    @test has_extra(factor_data, :test_key)
    @test get_extra(factor_data, :test_key) == "test_value"
    @test get_extra(factor_data, :nonexistent, "default") == "default"

    # Test CompileTimeDictionaryKey interface
    key = CompileTimeDictionaryKey{:typed_key, Int}()
    @test !has_extra(factor_data, key)
    set_extra!(factor_data, key, 42)
    @test has_extra(factor_data, key)
    @test get_extra(factor_data, key) == 42
    @test get_extra(factor_data, CompileTimeDictionaryKey{:nonexistent, Float64}(), 3.14) == 3.14
end

@testitem "NodeCreationOptions" setup = [TestUtils] begin
    import GraphPPL: NodeCreationOptions, withopts, withoutopts

    @test NodeCreationOptions() == NodeCreationOptions()
    @test keys(NodeCreationOptions()) === ()
    @test NodeCreationOptions(arbitrary_option = 1) == NodeCreationOptions((; arbitrary_option = 1))

    @test haskey(NodeCreationOptions(arbitrary_option = 1), :arbitrary_option)
    @test NodeCreationOptions(arbitrary_option = 1)[:arbitrary_option] === 1

    @test @inferred(haskey(NodeCreationOptions(), :a)) === false
    @test @inferred(haskey(NodeCreationOptions(), :b)) === false
    @test @inferred(haskey(NodeCreationOptions(a = 1, b = 2), :b)) === true
    @test @inferred(haskey(NodeCreationOptions(a = 1, b = 2), :c)) === false
    @test @inferred(NodeCreationOptions(a = 1, b = 2)[:a]) === 1
    @test @inferred(NodeCreationOptions(a = 1, b = 2)[:b]) === 2

    @test_throws ErrorException NodeCreationOptions()[:a]
    @test_throws ErrorException NodeCreationOptions(a = 1, b = 2)[:c]

    @test @inferred(get(NodeCreationOptions(), :a, 2)) === 2
    @test @inferred(get(NodeCreationOptions(), :b, 3)) === 3
    @test @inferred(get(NodeCreationOptions(), :c, 4)) === 4
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :a, 2)) === 1
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :b, 3)) === 2
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :c, 4)) === 4

    @test NodeCreationOptions(a = 1, b = 2)[(:a,)] === NodeCreationOptions(a = 1)
    @test NodeCreationOptions(a = 1, b = 2)[(:b,)] === NodeCreationOptions(b = 2)

    @test keys(NodeCreationOptions(a = 1, b = 2)) == (:a, :b)

    @test @inferred(withopts(NodeCreationOptions(), (a = 1,))) == NodeCreationOptions(a = 1)
    @test @inferred(withopts(NodeCreationOptions(b = 2), (a = 1,))) == NodeCreationOptions(b = 2, a = 1)

    @test @inferred(withoutopts(NodeCreationOptions(), Val((:a,)))) == NodeCreationOptions()
    @test @inferred(withoutopts(NodeCreationOptions(b = 1), Val((:a,)))) == NodeCreationOptions(b = 1)
    @test @inferred(withoutopts(NodeCreationOptions(a = 1), Val((:a,)))) == NodeCreationOptions()
    @test @inferred(withoutopts(NodeCreationOptions(a = 1, b = 2), Val((:c,)))) == NodeCreationOptions(a = 1, b = 2)
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