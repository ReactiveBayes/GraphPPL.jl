using BenchmarkTools
using GraphPPL


include("model_zoo.jl")

function benchmark_model_creation()
    SUITE = BenchmarkGroup()
    for i in 5:2:15
        SUITE["create HGF of depth $i"] = @benchmarkable create_hgf($i)
    end
    return SUITE
end