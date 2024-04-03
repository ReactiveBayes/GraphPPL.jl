# GraphPPL.jl Documentation

Welcome to the documentation of `GraphPPL.jl`, a **P**robabilistic **P**rogramming **L**anguage for Julia for specifying probabilistic models in a form of a factor graph. `GraphPPL` is a high-level backend-agnostic PPL that supports nested graphical models, allowing hierarchical modeling and model specification. `GraphPPL` materializes your probabilistic models as a factor graph. Additionally, it support a plugin system, that allows specification of inference specific information for different methods, e.g. variational inference. `GraphPPL` is designed to be a flexible and extensible PPL, and supports user-defined nodes and transformations. 

It is important to note that `GraphPPL.jl` is not an inference package and does not run inference in the specified models.
For inference, you may need a `GraphPPL.jl` compatible package, for example [`RxInfer.jl`](https://rxinfer.ml).

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
