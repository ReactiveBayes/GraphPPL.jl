@testitem "lazy_bool_allequal" begin
    import GraphPPL: lazy_bool_allequal

    @testset begin
        itr = [1, 2, 3, 4]

        outcome, value = lazy_bool_allequal(x -> x > 0, itr)
        @test outcome === true
        @test value === true

        outcome, value = lazy_bool_allequal(x -> x < 0, itr)
        @test outcome === true
        @test value === false
    end

    @testset begin
        itr = [1, 2, -1, -2]

        outcome, value = lazy_bool_allequal(x -> x > 0, itr)
        @test outcome === false
        @test value === true

        outcome, value = lazy_bool_allequal(x -> x < 0, itr)
        @test outcome === false
        @test value === false
    end

    @testset begin
        # We do not support it for now, but we can add it in the future
        @test_throws ErrorException lazy_bool_allequal(x -> x > 0, [])
    end
end
