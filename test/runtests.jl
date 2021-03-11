module GraphPPLTest

using Test, Documenter, GraphPPL

doctest(GraphPPL)

@testset "GraphPPL" begin

    @testset "Detect ambiguities" begin
        @test length(Test.detect_ambiguities(GraphPPL)) == 0
    end

end

end