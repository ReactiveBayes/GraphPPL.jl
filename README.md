# GraphPPL

| **Documentation**                                                         | **Build Status**                 | **Coverage**                       |
|:-------------------------------------------------------------------------:|:--------------------------------:|:----------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![DOI][ci-img]][ci-url]         |[![Codecov][codecov-img]][codecov-url] |

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://reactivebayes.github.io/GraphPPL.jl/dev

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://reactivebayes.github.io/GraphPPL.jl/stable

[ci-img]: https://github.com/reactivebayes/GraphPPL.jl/actions/workflows/ci.yml/badge.svg?branch=master
[ci-url]: https://github.com/reactivebayes/GraphPPL.jl/actions

[codecov-img]: https://codecov.io/gh/ReactiveBayes/GraphPPL.jl/graph/badge.svg?token=JESDYZVU9N
[codecov-url]: https://codecov.io/gh/ReactiveBayes/GraphPPL.jl

GraphPPL.jl is a probabilistic programming language focused on probabilistic graphical models. GraphPPL.jl materializes a probabilistic model as a factor graph and provides a set of tools for model specification. GraphPPL.jl is a part of the [RxInfer](https://rxinfer.ml) ecosystem, but it does not explicitly depend on any inference backend. GraphPPL exports a high-level DSL for model specification and allows users to append arbitrary information to nodes in the model. This information can be used by inference backends to perform inference on the model.

## Installation

To install GraphPPL.jl, you can use the Julia package manager. From the Julia REPL, type `]` to enter the Pkg REPL mode and run:

```julia
pkg> add GraphPPL
```

# Model Specification in GraphPPL

GraphPPL.jl provides a high-level DSL for model specification. The DSL is based on the [Julia's](https://julialang.org) macro system and allows users to specify probabilistic models in a concise and intuitive way. The DSL is based on the following principles:

- **Model specification should read as a Julia program**. GraphPPL.jl introduces the `~` syntax for model specification. 
- **Any GraphPPL model is a valid submodel**. GraphPPL.jl allows users to specify models as a composition of submodels. This allows users to reuse models and specify complex models in a modular way.
- **Model specification should be extensible**. GraphPPL.jl allows users to extend the DSL with custom model specification procedures. This allows developers of inference backend to inject desired behavior to the model specification process.

To achieve tihs, GraphPPL.jl specifies a protocol for the `@model` macro:
```julia
@model function beta_bernoulli(x)
    θ ~ Beta(1, 1)
    for i in eachindex(x)
        x[i] ~ Bernoulli(θ)
    end
end
```

# Inference Backend

GraphPPL.jl does not export any Bayesian inference backend. It provides a complex DSL parser, model generation, constraints specification and meta specification helpers. To run inference on 
generated models a user needs to have a Bayesian inference backend with GraphPPL.jl support (e.g. [RxInfer.jl](https://rxinfer.ml)). 

# Documentation

For more information about GraphPPL.jl please refer to the [documentation](https://biaslab.github.io/GraphPPL.jl/stable).

> [!NOTE]
> `GraphPPL.jl` API has been changed in version `4.0.0`. See [Migration Guide](https://reactivebayes.github.io/GraphPPL.jl/stable/) for more details.


# License

[MIT License](LICENSE) Copyright (c) 2021-2024 BIASlab, 2024-present ReactiveBayes
