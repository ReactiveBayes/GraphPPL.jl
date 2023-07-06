using BenchmarkTools
using GraphPPL

function benchmark_graph_engine()
    SUITE = BenchmarkGroup()
    SUITE["create_model"] = @benchmarkable GraphPPL.create_model()
    return SUITE
end


