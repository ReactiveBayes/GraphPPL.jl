module GraphPPLTest

using Test, GraphPPL


@testset "GraphPPL" begin

    @testset "Detect ambiguities" begin
        @test length(Test.detect_ambiguities(GraphPPL)) == 0
    end

    include("utils.jl")
    include("model_macro.jl")
    include("graph_engine.jl")
    include("resizable_array.jl")
    include("iterable_interface_extensions.jl")

end

end
