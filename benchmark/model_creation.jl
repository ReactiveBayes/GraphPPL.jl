using BenchmarkTools
using GraphPPL


include("model_zoo.jl")

function benchmark_model_creation()
    SUITE = BenchmarkGroup()
    for i in 10 .^ range(1, stop=3)
        SUITE["create HGF of depth $i"] = @benchmarkable create_hgf($i)
    end
    return SUITE
end