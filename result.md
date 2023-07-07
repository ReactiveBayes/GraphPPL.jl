# Benchmark Report for */Users/wnuijten/Documents/biaslab/GraphPPL.jl*

## Job Properties
* Time of benchmark: 7 Jul 2023 - 12:6
* Package commit: dirty
* Julia commit: e4ee48
* Julia command flags: None
* Environment variables: None

## Results
Below is a table of this job's results, obtained by running the benchmarks.
The values listed in the `ID` column have the structure `[parent_group, child_group, ..., key]`, and can be used to
index into the BaseBenchmarks suite to retrieve the corresponding benchmarks.
The percentages accompanying time and memory values in the below table are noise tolerances. The "true"
time/memory value for a given benchmark is expected to fall within this percentage of the reported value.
An empty cell means that the value was zero.

| ID                                                                                         | time            | GC time | memory          | allocations |
|--------------------------------------------------------------------------------------------|----------------:|--------:|----------------:|------------:|
| `["graph_engine", "create_model"]`                                                         |   1.004 μs (5%) |         |   6.84 KiB (1%) |          48 |
| `["graph_engine", "factor_node_creation", "Create factor node with 10 edges"]`             |  62.750 μs (5%) |         |  13.09 KiB (1%) |         315 |
| `["graph_engine", "factor_node_creation", "Create factor node with 15 edges"]`             |  61.917 μs (5%) |         |  13.09 KiB (1%) |         315 |
| `["graph_engine", "factor_node_creation", "Create factor node with 20 edges"]`             |  62.417 μs (5%) |         |  13.09 KiB (1%) |         315 |
| `["graph_engine", "factor_node_creation", "Create factor node with 25 edges"]`             |  62.541 μs (5%) |         |  13.09 KiB (1%) |         315 |
| `["graph_engine", "factor_node_creation", "Create factor node with 5 edges"]`              |  63.125 μs (5%) |         |  13.09 KiB (1%) |         315 |
| `["graph_engine", "variable_node_creation", "add 10 variable nodes"]`                      |   2.477 μs (5%) |         |   4.08 KiB (1%) |          61 |
| `["graph_engine", "variable_node_creation", "add 100 variable nodes"]`                     |  30.250 μs (5%) |         |  73.88 KiB (1%) |         607 |
| `["graph_engine", "variable_node_creation", "add 1000 variable nodes"]`                    | 246.625 μs (5%) |         | 227.64 KiB (1%) |        6490 |
| `["graph_engine", "variable_node_creation", "add_variable_node"]`                          | 415.514 ns (5%) |         |  160 bytes (1%) |           4 |
| `["graph_engine", "variable_node_creation", "getorcreate 10 variable nodes ascending"]`    | 439.601 ns (5%) |         |                 |             |
| `["graph_engine", "variable_node_creation", "getorcreate 10 variable nodes descending"]`   | 456.005 ns (5%) |         |                 |             |
| `["graph_engine", "variable_node_creation", "getorcreate 10 variable nodes that exist"]`   | 429.437 ns (5%) |         |                 |             |
| `["graph_engine", "variable_node_creation", "getorcreate 100 variable nodes ascending"]`   |   4.214 μs (5%) |         |                 |             |
| `["graph_engine", "variable_node_creation", "getorcreate 100 variable nodes descending"]`  |   4.262 μs (5%) |         |                 |             |
| `["graph_engine", "variable_node_creation", "getorcreate 100 variable nodes that exist"]`  |   4.214 μs (5%) |         |                 |             |
| `["graph_engine", "variable_node_creation", "getorcreate 1000 variable nodes ascending"]`  |  43.458 μs (5%) |         |   7.64 KiB (1%) |         489 |
| `["graph_engine", "variable_node_creation", "getorcreate 1000 variable nodes descending"]` |  44.041 μs (5%) |         |   7.64 KiB (1%) |         489 |
| `["graph_engine", "variable_node_creation", "getorcreate 1000 variable nodes that exist"]` |  43.500 μs (5%) |         |   7.64 KiB (1%) |         489 |
| `["model_creation", "create HGF of depth 11"]`                                             |   7.185 ms (5%) |         | 408.95 KiB (1%) |        7684 |
| `["model_creation", "create HGF of depth 13"]`                                             |   8.571 ms (5%) |         | 473.20 KiB (1%) |        9044 |
| `["model_creation", "create HGF of depth 15"]`                                             |  10.042 ms (5%) |         | 537.45 KiB (1%) |       10404 |
| `["model_creation", "create HGF of depth 5"]`                                              |   2.893 ms (5%) |         | 213.34 KiB (1%) |        3597 |
| `["model_creation", "create HGF of depth 7"]`                                              |   4.324 ms (5%) |         | 277.58 KiB (1%) |        4957 |
| `["model_creation", "create HGF of depth 9"]`                                              |   5.748 ms (5%) |         | 343.45 KiB (1%) |        6321 |

## Benchmark Group List
Here's a list of all the benchmark groups executed by this job:

- `["graph_engine"]`
- `["graph_engine", "factor_node_creation"]`
- `["graph_engine", "variable_node_creation"]`
- `["model_creation"]`

## Julia versioninfo
```
Julia Version 1.9.2
Commit e4ee485e909 (2023-07-05 09:39 UTC)
Platform Info:
  OS: macOS (arm64-apple-darwin22.4.0)
  uname: Darwin 22.5.0 Darwin Kernel Version 22.5.0: Thu Jun  8 22:22:20 PDT 2023; root:xnu-8796.121.3~7/RELEASE_ARM64_T6000 arm64 arm
  CPU: Apple M1 Pro: 
              speed         user         nice          sys         idle          irq
       #1  2400 MHz     495556 s          0 s     339368 s    1523302 s          0 s
       #2  2400 MHz     496415 s          0 s     319517 s    1542644 s          0 s
       #3  2400 MHz     332494 s          0 s     119588 s    1909856 s          0 s
       #4  2400 MHz     226423 s          0 s      71098 s    2067772 s          0 s
       #5  2400 MHz     142226 s          0 s      39295 s    2185746 s          0 s
       #6  2400 MHz     114902 s          0 s      25842 s    2227354 s          0 s
       #7  2400 MHz      63455 s          0 s      12246 s    2293375 s          0 s
       #8  2400 MHz      37807 s          0 s       7217 s    2324524 s          0 s
  Memory: 32.0 GB (2269.9375 MB free)
  Uptime: 1.284655e6 sec
  Load Avg:  2.89599609375  2.513671875  2.5029296875
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-14.0.6 (ORCJIT, apple-m1)
  Threads: 1 on 6 virtual cores
```