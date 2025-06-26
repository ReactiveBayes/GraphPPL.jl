@testitem "0D index properties" begin
    using Static, JET
    import GraphPPL: Index, get_index_dimensionality

    index = Index()

    @test @inferred get_index_dimensionality(index) == StaticInt(0)
    JET.@test_opt get_index_dimensionality(index)
    @test @allocated(get_index_dimensionality(index)) == 0
end

@testitem "1D index properties" begin
    using Static, JET
    import GraphPPL: Index, get_index_dimensionality

    index = Index(1)

    @test @inferred get_index_dimensionality(index) == StaticInt(1)
    JET.@test_opt get_index_dimensionality(index)
    @test @allocated(get_index_dimensionality(index)) == 0
end

@testitem "2D index properties" begin
    using Static, JET
    import GraphPPL: Index, get_index_dimensionality

    index = Index(1, 2)

    @test @inferred get_index_dimensionality(index) == StaticInt(2)
    JET.@test_opt get_index_dimensionality(index)
    @test @allocated(get_index_dimensionality(index)) == 0
end

@testitem "2+D index properties" begin
    using Static, JET
    import GraphPPL: Index, get_index_dimensionality

    for dims in 3:10
        args = [1:dims...]

        index = Index(args...)

        @test get_index_dimensionality(index) == StaticInt(dims)
        JET.@test_opt get_index_dimensionality(index)
        @test @allocated(get_index_dimensionality(index)) == 0
    end
end