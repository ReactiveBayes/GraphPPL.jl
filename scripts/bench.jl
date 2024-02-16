using GraphPPL
using BenchmarkTools
using PkgBenchmark

result, name = if ARGS == []
    PkgBenchmark.benchmarkpkg(GraphPPL), "current"
else
    BenchmarkTools.judge(GraphPPL, ARGS[1]; time_tolerance = 0.1, memory_tolerance = 0.05), ARGS[1]
end

export_markdown("benchmark_vs_$(name)_result.md", result; export_invariants = true)
