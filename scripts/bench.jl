using GraphPPL
using BenchmarkTools
using PkgBenchmark

result, name = if ARGS == []
    PkgBenchmark.benchmarkpkg(GraphPPL), "current"
else
    BenchmarkTools.judge(GraphPPL, ARGS[1]), ARGS[1]
end

export_markdown("benchmark_vs_$(name)_result.md", result)
