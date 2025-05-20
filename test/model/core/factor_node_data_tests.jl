@testitem "FactorNodeData constructor" begin
    import GraphPPL: FactorNodeData, get_functional_form, get_context

    # Test constructor with form only
    factor_data = FactorNodeData("test_form")
    @test get_functional_form(factor_data) == "test_form"
    @test get_context(factor_data) === nothing
    @test isempty(factor_data.extras)

    # Test constructor with form and context
    context = "test_context"
    factor_data = FactorNodeData("test_form", context)
    @test get_functional_form(factor_data) == "test_form"
    @test get_context(factor_data) === context
    @test isempty(factor_data.extras)
end

@testitem "FactorNodeData implements get_functional_form and get_context" begin
    import GraphPPL: FactorNodeData, get_functional_form, get_context

    form = "test_form"
    context = "test_context"
    factor_data = FactorNodeData(form, context)

    @test get_functional_form(factor_data) === form
    @test get_context(factor_data) === context
end

@testitem "FactorNodeData implements has_extra with Symbol keys" begin
    import GraphPPL: FactorNodeData, has_extra, set_extra!

    factor_data = FactorNodeData("test_form")

    # Initially, no extras should exist
    @test !has_extra(factor_data, :test_key)

    # After setting an extra, it should exist
    set_extra!(factor_data, :test_key, "test_value")
    @test has_extra(factor_data, :test_key)

    # Non-existent keys should return false
    @test !has_extra(factor_data, :nonexistent_key)
end

@testitem "FactorNodeData implements has_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: FactorNodeData, has_extra, set_extra!, CompileTimeDictionaryKey

    factor_data = FactorNodeData("test_form")
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
    import GraphPPL: FactorNodeData, get_extra, set_extra!

    factor_data = FactorNodeData("test_form")

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
    import GraphPPL: FactorNodeData, get_extra, set_extra!, CompileTimeDictionaryKey

    factor_data = FactorNodeData("test_form")
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
    import GraphPPL: FactorNodeData, get_extra, set_extra!

    factor_data = FactorNodeData("test_form")

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
    import GraphPPL: FactorNodeData, get_extra, set_extra!, CompileTimeDictionaryKey

    factor_data = FactorNodeData("test_form")
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set new extras with type safety
    @test set_extra!(factor_data, string_key, "test_value") == "test_value"
    @test set_extra!(factor_data, int_key, 42) == 42

    @test get_extra(factor_data, string_key) == "test_value"
    @test get_extra(factor_data, int_key) == 42

    # Overwrite existing extras
    @test set_extra!(factor_data, string_key, "new_value") == "new_value"
    @test get_extra(factor_data, string_key) == "new_value"
end

@testitem "FactorNodeData show method" begin
    import GraphPPL: FactorNodeData, set_extra!

    factor_data = FactorNodeData("test_form", "test_context")
    set_extra!(factor_data, :test_key, "test_value")

    # Test string representation
    str = sprint(show, factor_data)
    @test occursin("FactorNodeData", str)
    @test occursin("test_form", str)
    @test occursin("test_context", str)
    @test occursin("test_key", str)
    @test occursin("test_value", str)
end

@testitem "FactorNodeData satisfies FactorNodeDataInterface" begin
    import GraphPPL:
        FactorNodeData,
        FactorNodeDataInterface,
        get_functional_form,
        get_context,
        has_extra,
        get_extra,
        set_extra!,
        CompileTimeDictionaryKey

    # Verify FactorNodeData is a subtype of FactorNodeDataInterface
    @test FactorNodeData <: FactorNodeDataInterface

    # Create a test instance
    factor_data = FactorNodeData("test_form", "test_context")

    # Test all interface methods are implemented
    @test get_functional_form(factor_data) == "test_form"
    @test get_context(factor_data) == "test_context"

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

@testitem "create_factor_data function" begin
    import GraphPPL: FactorNodeData, create_factor_data, get_functional_form, get_context

    # Test basic creation
    form = "test_form"
    context = "test_context"
    factor_data = create_factor_data(FactorNodeData, context, form)

    # Verify the created data has correct form and context
    @test factor_data isa FactorNodeData
    @test get_functional_form(factor_data) === form
    @test get_context(factor_data) === context
    @test isempty(factor_data.extras)

    # Test with kwargs (should be ignored as per implementation)
    factor_data_with_kwargs = create_factor_data(FactorNodeData, context, form; extra_param = 42)
    @test factor_data_with_kwargs isa FactorNodeData
    @test get_functional_form(factor_data_with_kwargs) === form
    @test get_context(factor_data_with_kwargs) === context
    @test isempty(factor_data_with_kwargs.extras)
end
