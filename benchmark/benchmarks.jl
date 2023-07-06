using BenchmarkTools

const SUITE = BenchmarkGroup()
include("graph_engine.jl")
SUITE["graph_engine"] = benchmark_graph_engine()
include("model_creation.jl")
SUITE["model_creation"] = model_creation_benchmarks()