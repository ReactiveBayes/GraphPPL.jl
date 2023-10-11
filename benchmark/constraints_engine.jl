using GraphPPL
using BenchmarkTools

include("model_zoo.jl")

function benchmark_constraints_engine()
    SUITE = BenchmarkGroup()
    model = create_hgf(5)
    c = gethgfconstraints()
    SUITE["apply_constraints_hgf"] = @benchmarkable GraphPPL.apply!(m, $c) setup=(m=deepcopy($model)) evals=1

    for j in 2:4
        n_nodes = 10^j
        model = create_longarray(n_nodes)
        c = longarrayconstraints()
        SUITE["apply meanfield constraint to vector of $n_nodes variables"]  = @benchmarkable GraphPPL.apply!(m, $c) setup=(m=deepcopy($model)) evals=1
    end
    return SUITE
end