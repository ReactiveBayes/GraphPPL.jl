using BenchmarkTools

const SUITE = BenchmarkGroup()

include("graph_engine.jl")
include("model_creation.jl")

SUITE["graph_engine"] = benchmark_graph_engine()
SUITE["model_creation"] = benchmark_model_creation()