module GraphPPLTest

using Test, GraphPPL


@testset "GraphPPL" begin

    @testset "Detect ambiguities" begin
        @test length(Test.detect_ambiguities(GraphPPL)) == 1
    end

    include("utils.jl")
    include("resizable_array.jl")
    include("bitset_tuple.jl")
    include("graph_engine.jl")
    include("model_macro.jl")
    include("constraints_engine.jl")
    include("constraints_macro.jl")
    include("meta_engine.jl")
    include("meta_macro.jl")

end

end
