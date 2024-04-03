# Getting Started

On this page we will cover the basic syntax of `GraphPPL` and will work towards a basic coin-toss example. 

## Installation

`GraphPPL.jl` is a registered Julia package. To install it, run the following command in the Julia REPL:
```julia
julia> using Pkg
julia> Pkg.add("GraphPPL")
```

This guide assumes you have `GraphPPL.jl` installed, as well as `Distributions.jl` to work with standard probability distributions as building blocks in our probabilistic programs.

```@example getting-started
using GraphPPL
using Distributions
```

## Creating a model

In `GraphPPL`, we can specify a model with the `@model` macro. The `@model` macro takes a function as an argument, and registers the blueprint of creating this model. The model macro is not exported by default by `GraphPPL` to allow inference packages to define their own `@model` macro on top of the `GraphPPL.jl`. For demonstration purposes we will import `GraphPPL.@model` explicitly:
    
```@example getting-started
import GraphPPL: @model
```

## Syntax

In general, we can write probabilistic programs in `GraphPPL` using the `~` operator. 
The `x ~ X` expression can be read as $x$ _sampled from_ $X$. For example, if we want to define a random variable `x` that is distributed according to a normal distribution with mean 0 and variance 1, we can write:

```@example getting-started
@model function example()
    x ~ Normal(0, 1)
end
```

We can also define multiple random variables in the same model:

```@example getting-started
@model function example()
    x ~ Normal(0, 1)
    y ~ Normal(0, 1)
end
```

or use our newly defined random variables as parameters for other distributions:

```@example getting-started
@model function example()
    x ~ Normal(0, 1)
    y ~ Normal(x, 1)
end
```

We can also use the `:=` operator to define deterministic relations:
    
```@example getting-started
@model function example()
    x ~ Normal(0, 1)
    y ~ Normal(x, 1)
    z := x + y
end
``` 

Note that a deterministic function, when called with known parameters, will not materialize in the factor graph, but will instead compile out and return the result. To illustrate this: 

```@example getting-started
@model function example()
    μ := 1 + 2
    x ~ Normal(μ, 1)
    y ~ Normal(x, 1)
    z := x + y
end
```

In the above example, the `μ := 1 + 2` line will not materialize in the factor graph, and instead will instantiate the variable `μ` with the value `3`. However, since `x` and `y` are random variables, the `+` operator will materialize in the factor graph.

## Inputs and interfaces

In `GraphPPL`, we can feed data and interfaces into the model through the function arguments. For example, if we want to define a model that takes in a vector of observations `x` that are all distributed according to a normal distribution with mean 0 and variance 1, we can write:

```@example getting-started
@model function example(x)
    for i in eachindex(x)
        x[i] ~ Normal(0, 1)
    end
end
```

Alternatively, we can use the broadcasting syntax from Julia, extended to work with the `~` operator:

```@example getting-started
@model function example(x)
    x .~ Normal(0, 1)
end
```

Note that interfaces do not need to be random variables; this distinction will be made during model construction. Until a variable is used as an input to a stochastic node, it will be treated as a regular variable. This allows us to write models that take in both data and parameters:

```@example getting-started
@model function recursive_model(x, depth)
    if depth == 0
        x ~ Normal(0, 1)
    else
        x ~ recursive_model(depth = depth - 1)
    end
end
```

Here, `x` is treated as a random variable since it is connected to a `Normal` node. However, `depth` is only used as a hyperparameter to define model structure and is not connected to any stochastic nodes, so it is treated as a regular variable. In this recursive model we also get to see nested models in action: the `recursive_model` is used as a submodel of itself. More on this in the [Nested Models](#nested-models) section.

!!! note
    Models defined with the `@model` macro have no positional arguments. All the arguments are converted to the keyword arguments.
    This also means that the models cannot use multiple dispatch, since multiple dispatch on keyword arguments is not supported in Julia.

## Bayesian Coin-Toss (Beta-Bernoulli model)

Now that we have a grasp on the basic syntax and semantics of `GraphPPL`, let's try to write a simple coin-toss model a.k.a Beta-Bernoulli model. We will start with a model that takes in a series of observations `x` that are i.i.d. distributed according to a Bernoulli distribution with parameter `θ`, where we put a Beta prior on `θ`:

```@example getting-started
@model function coin_toss(x)
    θ ~ Beta(1, 1)
    x .~ Bernoulli(θ)
end
```

## Instantiating the model 

To instantiate the model we need to pass the data `x`. We can do that with the [`GraphPPL.create_model`](@ref) function in combination with [`GraphPPL.LazyIndex`](@ref).

```@example getting-started
xdata = [ 1.0, 0.0, 0.0, 1.0 ]

model = GraphPPL.create_model(coin_toss()) do model, context
    return (; 
        # This expression creates data handle for `x` in the model using the `xdata` as the underlying collection
        x = GraphPPL.getorcreate!(model, context, GraphPPL.NodeCreationOptions(kind = :data), :x, GraphPPL.LazyIndex(xdata))
    )
end
nothing #hide
```

## Visualizing the model

`GraphPPL` exports a simple visualization function that can be used to visualize the factor graph of a model. This requires the `GraphPlot` and `Cairo` packages to be installed. To visualize the `coin_toss` model, we can run:

```@example getting-started
using GraphPlot, Cairo
GraphPlot.gplot(model)
```

## Syntax Guide

To dive into the specifics of the syntax of the model specification within `GraphPPL.jl` read the [Syntax Guide](@ref syntax-guide).
