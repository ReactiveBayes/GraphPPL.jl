module GraphPPLTest

using Test, GraphPPL


@testset "GraphPPL" begin

    @testset "Detect ambiguities" begin
        @test length(Test.detect_ambiguities(GraphPPL)) == 0
    end

    include("utils.jl")

end

end
