# GraphPPL

| **Documentation**                                                         | **Build Status**                 |
|:-------------------------------------------------------------------------:|:--------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![DOI][ci-img]][ci-url]         |

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://biaslab.github.io/GraphPPL.jl/dev

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://biaslab.github.io/GraphPPL.jl/stable

[ci-img]: https://github.com/biaslab/GraphPPL.jl/actions/workflows/ci.yml/badge.svg?branch=master
[ci-url]: https://github.com/biaslab/GraphPPL.jl/actions

GraphPPL.jl is a probabilistic programming language focused on probabilistic graphical models. This repository is aimed for advanced users, please refer to the [ReactiveMP.jl](https://github.com/biaslab/ReactiveMP.jl) repository for more comprehensive and self-contained documentation and usages examples.

# Inference Backend

GraphPPL.jl does not export any Bayesian inference backend. It provides a simple DSL parser, model generation, constraints specification and meta specification helpers. To run inference on 
generated models user needs to have a Bayesian inference backend with GraphPPL.jl support (e.g. [ReactiveMP.jl](https://github.com/biaslab/ReactiveMP.jl)). 

# License

[MIT License](LICENSE) Copyright (c) 2021-2023 BIASlab
