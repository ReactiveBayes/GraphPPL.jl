using BenchmarkTools

const SUITE = BenchmarkGroup()
include("graph_engine.jl")
include("model_creation.jl")
include("constraints_engine.jl")
SUITE["constraints_engine"] = benchmark_constraints_engine()
SUITE["graph_engine"] = benchmark_graph_engine()
SUITE["model_creation"] = benchmark_model_creation()