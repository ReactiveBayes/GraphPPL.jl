using GraphPPL
using BenchmarkTools

include("model_zoo.jl")

function benchmark_constraints_engine()
    SUITE = BenchmarkGroup()
    model = create_hgf(5)
    c = gethgfconstraints()
    SUITE["apply_constraints_hgf"] = @benchmarkable GraphPPL.apply!(m, $c) setup=(m=deepcopy($model)) evals=1

    for j in 10:5:20
        model = create_longarray(j)
        c = longarrayconstraints()
        SUITE["apply meanfield constraint to vector of $j variables"]  = @benchmarkable GraphPPL.apply!(m, $c) setup=(m=deepcopy($model)) evals=1
    end
    model = create_longarray(1000)
    c = longarrayconstraints()
    SUITE["apply meanfield constraint to vector of 1000 variables"]  = @benchmarkable GraphPPL.apply!(m, $c) setup=(m=deepcopy($model)) evals=1
    return SUITE
end