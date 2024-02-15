using BenchmarkTools

const SUITE = BenchmarkGroup()

# Many benchmarks require a model to be created, so we'll do that here
const modelsetup = quote
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
end

macro benchmarkable_withmodel(args...)
    return :(@benchmarkable $(args...) setup=$modelsetup)
end

include("graph_engine.jl")
# include("model_creation.jl")
# include("constraints_engine.jl")
# SUITE["constraints_engine"] = benchmark_constraints_engine()
SUITE["graph_engine"] = benchmark_graph_engine()
# SUITE["model_creation"] = benchmark_model_creation()