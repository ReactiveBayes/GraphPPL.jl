using GraphPPL
using BenchmarkTools
using PkgBenchmark

args = ARGS == [] ? ["benchmark"] : ARGS
arg = args[1]

result = BenchmarkTools.judge(GraphPPL, arg)
export_markdown("result.md", result)