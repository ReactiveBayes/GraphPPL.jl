using BenchmarkTools
using GraphPPL


include("model_zoo.jl")

function benchmark_model_creation()
    SUITE = BenchmarkGroup()
    for i in 10 .^ range(1, stop=3)
        SUITE["create HGF of depth $i"] = @benchmarkable create_hgf($i)
    end
    for i in 10 .^ range(2, stop=6)
        n_nodes = 10^i
        SUITE["create model with array of length $i"] = @benchmarkable create_longarray($n_nodes)
    end
    return SUITE
end