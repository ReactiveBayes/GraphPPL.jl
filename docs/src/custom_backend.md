# Customizing the behaviour of the `@model` with a custom backend

When creating the graphical model, `GraphPPL` package uses several functions to decide what to do in specific situations, for example

- Is `x ~ SomeType(y, z)` a stochastic or deterministic relationship? For example `SomeType` can be a `Gaussian`, in which case the answer
is obvious, but what is `SomeType` is a `Matrix`? Or what if a user specified `const Matrix = Gaussian`?
- Should `x ~ Normal(a, b)` be interpreted as `x ~ Normal(mean = a, variance = b)` or `Normal(mean = a, standard_deviation = b)`?
- Should `x_next ~ HierarchicalGaussianFilter(x_prev, tau)` create an `Atomic` or a `Composite` node for `HierarchicalGaussianFilter`? 
- Should `x := x1 + x2 + x3 + x4` be replaced with `x := sum(x1, x2, x3, x4)` or `x := sum(sum(sum(x1, x2), x3), x4)`. Or left untouched?
- What extra syntax transformations are allowed? For example should `not_x ~ ¬x` be interpreted as a boolean random variable `x` with the `¬` as a stochastic node
or it is just a function call?

It is not possible to resolve these issues on a _syntax level_, thus `GraphPPL` requires a specific _backend_ to resolve this information at run-time. 

## Default backend

For interactive purposes (plotting or testing) `GraphPPL` implements a `DefaultBackend`, but the `@model` macro by itself is not exported by default. To use it explicitly simply call:

```@example import-model-macro
import GraphPPL: @model
```

```@docs
GraphPPL.DefaultBackend
```

## Recommended way of using `GraphPPL` from a backend-specific inference package

A backend-specific inference package should implement its own backend structure together with its own `@model` macro (or a different name)
that would call the `@model` macro from `GraphPPL` with a specific package. Below is the list of backend-specific functions, each of which should be implemented 
in order for backend to be fully specified. 

```@docs
GraphPPL.model_macro_interior_pipelines
GraphPPL.NodeBehaviour
```