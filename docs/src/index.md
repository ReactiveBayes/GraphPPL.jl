# GraphPPL.jl Documentation

Welcome to the documentation of `GraphPPL.jl`, a Probabilistic Programming Language for Julia. `GraphPPL` is a high-level backend-agnostic PPL that supports nested graphical models, allowing hierarchical modeling and model specification. `GraphPPL` materializes your probabilistic models as a factor graph, and specifies a [Bethe Free Energy](https://biaslab.github.io/RxInfer.jl/stable/library/bethe-free-energy/) that inference backends can minimize. The Bethe Free Energy is a generalization of many well-known inference algorithms, such as Expectation Maximization, Laplace Approximation and Mean-Field Variational Inference. `GraphPPL` is designed to be a flexible and extensible PPL, and supports user-defined nodes and transformations. 

## Installation
`GraphPPL.jl` is a registered Julia package. To install it, run the following command in the Julia REPL:
```julia
julia> using Pkg
julia> Pkg.add("GraphPPL")
```


## Table of Contents

```@contents
Pages = [
  "getting_started.md",
  "nested_models.md",
  "constraint_specification.md",
  "plugins.md",
  "migration.md",
  "developers_guide.md",
  "custom_backend.md",
  "reference.md"
]
Depth = 2
```

## Index

```@index
```
