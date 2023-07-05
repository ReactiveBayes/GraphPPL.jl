module test_bitset_tuple

using Test
using TestSetExtensions
using GraphPPL

@testset "BitSetTuple" begin
    @testset "constructor" begin
        import GraphPPL: BitSetTuple, getconstraint
        for i = 1:10
            @test getconstraint(BitSetTuple(i)) == Tuple([BitSet(1:i) for _ = 1:i])
        end
        @test getconstraint(BitSetTuple([[1], [2], [3]])) ==
              Tuple([BitSet(1), BitSet(2), BitSet(3)])
    end

    @testset "intersect!" begin
        import GraphPPL: BitSetTuple, intersect!

        left = BitSetTuple(4)
        right = BitSetTuple(4)
        intersect!(left, right)
        @test left == BitSetTuple(4)

        left = BitSetTuple(3)
        right = BitSetTuple(4)
        @test_throws MethodError intersect!(left, right)

        left = BitSetTuple(4)
        right = BitSetTuple([collect(1:i) for i = 1:4])
        intersect!(left, right)
        @test left == right
    end

    @testset "complete!" begin
        import GraphPPL: BitSetTuple, complete!

        c = BitSetTuple([Int64[], Int64[], Int64[], [2], Int64[], Int64[], [3], [1]])
        complete!(c, 4)
        @test c == BitSetTuple([
            Int64[4],
            Int64[4],
            Int64[4],
            [2, 4],
            Int64[4],
            Int64[4],
            [3, 4],
            [1, 4],
        ])

    end

    @testset "convert_to_constraint" begin
        import GraphPPL: BitSetTuple, convert_to_constraint

        c = BitSetTuple([
            Int64[4],
            Int64[4],
            Int64[4],
            [2, 4],
            Int64[4],
            Int64[4],
            [3, 4],
            [1, 4],
        ])
        @test convert_to_constraint(c, 4) == BitSetTuple([
            BitSet([1, 4]),
            BitSet([2, 4]),
            BitSet([3, 4]),
            BitSet([1, 2, 3, 4]),
        ])

    end
end

end
