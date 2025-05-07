@testitem "mean_field_constraint!" begin
    using BitSetTuples
    import GraphPPL: mean_field_constraint!

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5))) == ((1,), (2,), (3,), (4,), (5,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(10))) == ((1,), (2,), (3,), (4,), (5,), (6,), (7,), (8,), (9,), (10,))

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(1), 1)) == ((1,),)
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), 3)) ==
        ((1, 2, 4, 5), (1, 2, 4, 5), (3,), (1, 2, 4, 5), (1, 2, 4, 5))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(1), (1,))) == ((1,),)
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(2), (1,))) == ((1,), (2,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(2), (2,))) == ((1,), (2,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), (1, 2))) == ((1,), (2,), (3, 4, 5), (3, 4, 5), (3, 4, 5))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), (1, 3, 5))) == ((1,), (2, 4), (3,), (2, 4), (5,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), (1, 2, 3, 4, 5))) == ((1,), (2,), (3,), (4,), (5,))
    @test_throws BoundsError mean_field_constraint!(BoundedBitSetTuple(5), (1, 2, 3, 4, 5, 6)) == ((1,), (2,), (3,), (4,), (5,))
end