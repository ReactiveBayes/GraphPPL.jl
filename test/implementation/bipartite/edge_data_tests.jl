@testitem "EdgeData creation with `create_edge_data`" begin
    import GraphPPL: EdgeData, get_name, get_index, create_edge_data

    # Test basic creation
    edge = create_edge_data(EdgeData, name = :test)
    @test get_name(edge) === :test
    @test get_index(edge) === nothing

    # Test with all fields
    edge = create_edge_data(EdgeData, name = :full_test, index = 2)
    @test get_name(edge) === :full_test
    @test get_index(edge) === 2
end

@testitem "EdgeData implements has_extra with Symbol keys" begin
    import GraphPPL: EdgeData, has_extra, get_extra, set_extra!, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)

    # Initially, no extras should exist
    @test !has_extra(edge, :test_key)

    # After setting an extra, it should exist
    set_extra!(edge, :test_key, "test_value")
    @test has_extra(edge, :test_key)
    @test get_extra(edge, :test_key) == "test_value"

    # Non-existent keys should return false
    @test !has_extra(edge, :nonexistent_key)
end

@testitem "EdgeData implements has_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: EdgeData, has_extra, set_extra!, CompileTimeDictionaryKey, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)
    key = CompileTimeDictionaryKey{:test_key, String}()

    # Initially, no extras should exist
    @test !has_extra(edge, key)

    # After setting an extra, it should exist
    set_extra!(edge, key, "test_value")
    @test has_extra(edge, key)

    # Different key should not exist
    other_key = CompileTimeDictionaryKey{:other_key, Int}()
    @test !has_extra(edge, other_key)
end

@testitem "EdgeData implements get_extra with Symbol keys" begin
    import GraphPPL: EdgeData, get_extra, set_extra!, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)

    # Set and get an extra
    set_extra!(edge, :test_key, "test_value")
    @test get_extra(edge, :test_key) == "test_value"

    # Get with default for existing key
    @test get_extra(edge, :test_key, "default") == "test_value"

    # Get with default for non-existent key
    @test get_extra(edge, :nonexistent_key, "default") == "default"

    # Getting non-existent key without default should throw
    @test_throws KeyError get_extra(edge, :nonexistent_key)
end

@testitem "EdgeData implements get_extra with CompileTimeDictionaryKey" begin
    import GraphPPL: EdgeData, get_extra, set_extra!, CompileTimeDictionaryKey, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set and get extras with type safety
    set_extra!(edge, string_key, "test_value")
    set_extra!(edge, int_key, 42)

    @test @inferred(get_extra(edge, string_key)) == "test_value"
    @test @inferred(get_extra(edge, int_key)) == 42

    # Get with default for existing key
    @test @inferred(get_extra(edge, string_key, "default")) == "test_value"
    @test @inferred(get_extra(edge, int_key, 0)) == 42

    # Get with default for non-existent key
    float_key = CompileTimeDictionaryKey{:float_key, Float64}()
    @test get_extra(edge, float_key, 3.14) == 3.14

    # Type safety check - should return the correct type
    @test get_extra(edge, int_key) isa Int
    @test get_extra(edge, string_key) isa String
end

@testitem "EdgeData implements set_extra! with Symbol keys" begin
    import GraphPPL: EdgeData, get_extra, set_extra!, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)

    # Set a new extra
    @test set_extra!(edge, :test_key, "test_value") == "test_value"
    @test get_extra(edge, :test_key) == "test_value"

    # Overwrite an existing extra
    @test set_extra!(edge, :test_key, "new_value") == "new_value"
    @test get_extra(edge, :test_key) == "new_value"

    # Set extras of different types
    @test set_extra!(edge, :int_key, 42) == 42
    @test set_extra!(edge, :bool_key, true) == true

    @test get_extra(edge, :int_key) == 42
    @test get_extra(edge, :bool_key) == true
end

@testitem "EdgeData implements set_extra! with CompileTimeDictionaryKey" begin
    import GraphPPL: EdgeData, get_extra, set_extra!, CompileTimeDictionaryKey, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)
    string_key = CompileTimeDictionaryKey{:string_key, String}()
    int_key = CompileTimeDictionaryKey{:int_key, Int}()

    # Set new extras with type safety
    @test set_extra!(edge, string_key, "test_value") == "test_value"
    @test set_extra!(edge, int_key, 42) == 42

    @test get_extra(edge, string_key) == "test_value"
    @test get_extra(edge, int_key) == 42

    # Overwrite existing extras
    @test set_extra!(edge, string_key, "new_value") == "new_value"
    @test get_extra(edge, string_key) == "new_value"
end

@testitem "EdgeData show method" begin
    import GraphPPL: EdgeData, set_extra!, create_edge_data

    edge = create_edge_data(EdgeData, name = :test)
    set_extra!(edge, :test_key, "test_value")

    # Test string representation
    str = sprint(show, edge)
    @test occursin("EdgeData", str)
    @test occursin(":test", str)
    @test occursin("test_key", str)
    @test occursin("test_value", str)
end

@testitem "EdgeData satisfies EdgeDataInterface" begin
    import GraphPPL:
        EdgeData, EdgeDataInterface, get_name, get_index, has_extra, get_extra, set_extra!, CompileTimeDictionaryKey, create_edge_data

    # Verify EdgeData is a subtype of EdgeDataInterface
    @test EdgeData <: EdgeDataInterface

    # Create a test instance
    edge = create_edge_data(EdgeData, name = :test, index = 1)

    # Test all interface methods are implemented
    @test get_name(edge) === :test
    @test get_index(edge) === 1

    # Test extras management
    @test !has_extra(edge, :test_key)
    set_extra!(edge, :test_key, "test_value")
    @test has_extra(edge, :test_key)
    @test get_extra(edge, :test_key) == "test_value"
    @test get_extra(edge, :nonexistent, "default") == "default"

    # Test CompileTimeDictionaryKey interface
    key = CompileTimeDictionaryKey{:typed_key, Int}()
    @test !has_extra(edge, key)
    set_extra!(edge, key, 42)
    @test has_extra(edge, key)
    @test get_extra(edge, key) == 42
    @test get_extra(edge, CompileTimeDictionaryKey{:nonexistent, Float64}(), 3.14) == 3.14
end