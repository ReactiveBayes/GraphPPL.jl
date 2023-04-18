module GraphPPLTest

using Test, GraphPPL


@testset "GraphPPL" begin

    @testset "Detect ambiguities" begin
        @test length(Test.detect_ambiguities(GraphPPL)) == 1
    end

    include("utils.jl")
    include("model_macro.jl")
    include("graph_engine.jl")
    include("resizable_array.jl")

end

end
