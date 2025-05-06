
@testitem "model constructor" begin
    import GraphPPL: create_model, Model

    include("testutils.jl")

    @test typeof(create_test_model()) <: Model

    @test_throws MethodError Model()
end

# TODO this is not a test for GraphPPL but for the tests.
@testitem "create_test_model()" begin
    import GraphPPL: create_model, Model, nv, ne

    include("testutils.jl")

    model = create_test_model()
    @test typeof(model) <: Model && nv(model) == 0 && ne(model) == 0

    @test_throws MethodError create_test_model(:x, :y, :z)
end

@testitem "getcounter and setcounter!" begin
    import GraphPPL: create_model, setcounter!, getcounter

    include("testutils.jl")

    model = create_test_model()

    @test setcounter!(model, 1) == 1
    @test getcounter(model) == 1
    @test setcounter!(model, 2) == 2
    @test getcounter(model) == 2
    @test setcounter!(model, getcounter(model) + 1) == 3
    @test setcounter!(model, 100) == 100
    @test getcounter(model) == 100
end